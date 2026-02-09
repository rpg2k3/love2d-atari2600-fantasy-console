-- src/os/cart_manager.lua  Cartridge discovery, loading, and save path management
local Config    = require("src.config")
local Serialize = require("src.util.serialize")
local Sprite    = require("src.gfx.sprite")
local Tile      = require("src.gfx.tile")
local Music     = require("src.audio.music")

local CartManager = {}

local currentCart = nil  -- { dir, path, meta, main }

-- ============================================================
-- Discovery: scan cartridges/ for valid carts
-- ============================================================
function CartManager.discover()
    local carts = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, Config.CARTS_DIR)
    if not ok or not items then return carts end

    for _, dir in ipairs(items) do
        local dirPath = Config.CARTS_DIR .. "/" .. dir
        local info = love.filesystem.getInfo(dirPath)
        if info and info.type == "directory" then
            local cartFile = dirPath .. "/cart.lua"
            if love.filesystem.getInfo(cartFile) then
                local meta = CartManager.loadMeta(dir)
                if meta then
                    carts[#carts + 1] = meta
                end
            end
        end
    end

    table.sort(carts, function(a, b) return (a.name or "") < (b.name or "") end)
    return carts
end

-- ============================================================
-- Load cart metadata from cart.lua
-- ============================================================
function CartManager.loadMeta(dir)
    local path = Config.CARTS_DIR .. "/" .. dir .. "/cart.lua"
    local data = Serialize.load(path)
    if not data or type(data) ~= "table" then return nil end
    data.dir  = dir
    data.path = Config.CARTS_DIR .. "/" .. dir
    data.name        = data.name or dir
    data.author      = data.author or "Unknown"
    data.version     = data.version or "1.0"
    data.description = data.description or ""
    data.color       = data.color or 3
    return data
end

-- ============================================================
-- Load and activate a cartridge
-- ============================================================
function CartManager.loadCart(cartInfo)
    Music.stop()

    local cartDir = cartInfo.dir

    -- Set up per-cart save paths
    Config.LEVELS_DIR        = Config.CART_SAVE_DIR .. "/" .. cartDir .. "/levels"
    Config.CONTENT_SAVE_PATH = Config.CART_SAVE_DIR .. "/" .. cartDir .. "/content.lua"

    -- Create save directories
    love.filesystem.createDirectory(Config.CART_SAVE_DIR .. "/" .. cartDir)
    love.filesystem.createDirectory(Config.LEVELS_DIR)

    -- Load cart content module
    local contentModPath = cartInfo.path:gsub("/", ".") .. ".content"
    package.loaded[contentModPath] = nil  -- clear cache for reload
    local cOk, content = pcall(require, contentModPath)
    if cOk and content then
        CartManager.registerContent(content)
    else
        print("[CART] No content or load error: " .. tostring(content))
    end

    -- Load cart main module
    local mainModPath = cartInfo.path:gsub("/", ".") .. ".main"
    package.loaded[mainModPath] = nil
    local mOk, mainMod = pcall(require, mainModPath)
    if not mOk or not mainMod then
        print("[CART] Main load error: " .. tostring(mainMod))
        -- Restore default paths on failure
        Config.LEVELS_DIR        = Config.DEFAULT_LEVELS_DIR
        Config.CONTENT_SAVE_PATH = "save/content.lua"
        return nil
    end

    currentCart = {
        dir  = cartDir,
        path = cartInfo.path,
        meta = cartInfo,
        main = mainMod,
    }

    -- Call cart's load with the engine API
    if mainMod.load then
        mainMod.load(CartManager.buildAPI())
    end

    return mainMod
end

-- ============================================================
-- Unload current cartridge
-- ============================================================
function CartManager.unloadCart()
    if currentCart and currentCart.main and currentCart.main.unload then
        currentCart.main.unload()
    end

    Music.stop()

    -- Clear require cache for the cart modules
    if currentCart then
        local contentPath = currentCart.path:gsub("/", ".") .. ".content"
        local mainPath    = currentCart.path:gsub("/", ".") .. ".main"
        package.loaded[contentPath] = nil
        package.loaded[mainPath]    = nil
    end

    -- Restore default paths
    Config.LEVELS_DIR        = Config.DEFAULT_LEVELS_DIR
    Config.CONTENT_SAVE_PATH = "save/content.lua"

    currentCart = nil
end

-- ============================================================
-- Register content (sprites, tiles, music) from a content table
-- ============================================================
function CartManager.registerContent(content)
    if content.sprites then
        for id, def in pairs(content.sprites) do
            Sprite.define(id, def.grid, def.w, def.h)
        end
    end
    if content.tiles then
        for id, def in pairs(content.tiles) do
            Tile.define(id, def.grid, def.flags, def.w, def.h)
        end
    end
    if content.music then
        Music.import(content.music)
    end
end

-- ============================================================
-- Build engine API table for carts
-- ============================================================
function CartManager.buildAPI()
    local Video     = require("src.platform.video")
    local Input     = require("src.util.input")
    local Palette   = require("src.gfx.palette")
    local PixelFont = require("src.util.pixelfont")
    local Camera    = require("src.gfx.camera")
    local SFX       = require("src.audio.sfx")
    local Tilemap   = require("src.gfx.tilemap")
    local World     = require("src.ecs.ecs")

    return {
        -- Graphics
        sprite   = Sprite,
        tile     = Tile,
        tilemap  = Tilemap,
        palette  = Palette,
        camera   = Camera,
        font     = PixelFont,

        -- Audio
        sfx   = SFX,
        music = Music,

        -- Input
        input = Input,

        -- ECS
        ecs = World,

        -- Video helpers
        getWidth  = function() return Video.getInternalWidth() end,
        getHeight = function() return Video.getInternalHeight() end,

        -- Love graphics pass-through (safe subset)
        gfx = {
            setColor   = love.graphics.setColor,
            rectangle  = love.graphics.rectangle,
            line       = love.graphics.line,
            circle     = love.graphics.circle,
            draw       = love.graphics.draw,
            print      = love.graphics.print,
            push       = love.graphics.push,
            pop        = love.graphics.pop,
            translate  = love.graphics.translate,
            setScissor = love.graphics.setScissor,
            clear      = love.graphics.clear,
        },

        -- Serialization (cart-scoped)
        save = function(filename, data)
            local path = CartManager.getSavePath(filename)
            return Serialize.save(path, data)
        end,
        load = function(filename)
            local path = CartManager.getSavePath(filename)
            return Serialize.load(path)
        end,
    }
end

-- ============================================================
-- Save path helpers
-- ============================================================
function CartManager.getSavePath(filename)
    if currentCart then
        local dir = Config.CART_SAVE_DIR .. "/" .. currentCart.dir
        love.filesystem.createDirectory(dir)
        return dir .. "/" .. filename
    end
    return "save/" .. filename
end

function CartManager.getCurrent()
    return currentCart
end

function CartManager.getCurrentName()
    if currentCart and currentCart.meta then
        return currentCart.meta.name
    end
    return nil
end

return CartManager
