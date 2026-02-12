-- src/os/cart_packager.lua  Export/Import cartridge packages (.cart.lua)
local Config = require("src.config")

local Packager = {}

-- ============================================================
-- Directory setup
-- ============================================================
function Packager.ensureDirs()
    love.filesystem.createDirectory(Config.EXPORTS_DIR)
    love.filesystem.createDirectory(Config.CARTS_DIR)
end

-- ============================================================
-- ID sanitization
-- ============================================================
function Packager.sanitizeId(raw)
    if not raw or raw == "" then return "cart" end
    local id = raw:lower()
    id = id:gsub("[%s%-]", "_")
    id = id:gsub("[^a-z0-9_]", "")
    if id == "" then id = "cart" end
    return id
end

function Packager.uniqueId(baseId, existingIds)
    if not existingIds[baseId] then return baseId end
    local n = 2
    while existingIds[baseId .. "_" .. n] do
        n = n + 1
    end
    return baseId .. "_" .. n
end

-- ============================================================
-- Text I/O helpers
-- ============================================================
function Packager.readText(path)
    local data, err = love.filesystem.read(path)
    return data, err
end

function Packager.writeText(path, text)
    local dir = path:match("(.+)/[^/]+$")
    if dir then love.filesystem.createDirectory(dir) end
    return love.filesystem.write(path, text)
end

-- ============================================================
-- Long-bracket string quoting (handles ]] inside text safely)
-- ============================================================
local function findBracketLevel(text)
    for level = 0, 10 do
        local close = "]" .. string.rep("=", level) .. "]"
        if not text:find(close, 1, true) then
            return level
        end
    end
    return nil
end

local function quoteLongString(text)
    local level = findBracketLevel(text)
    if level == nil then
        return string.format("%q", text)
    end
    local eq = string.rep("=", level)
    return "[" .. eq .. "[\n" .. text .. "]" .. eq .. "]"
end

-- ============================================================
-- Recursively collect .lua files from a directory
-- Returns array of relative paths (e.g. "cart.lua", "levels/LEVEL_01.lua")
-- ============================================================
local function collectFiles(basePath, relPath)
    local files = {}
    local fullPath = relPath ~= "" and (basePath .. "/" .. relPath) or basePath
    local ok, items = pcall(love.filesystem.getDirectoryItems, fullPath)
    if not ok or not items then return files end

    for _, item in ipairs(items) do
        local itemFull = fullPath .. "/" .. item
        local itemRel = relPath ~= "" and (relPath .. "/" .. item) or item
        local info = love.filesystem.getInfo(itemFull)
        if info then
            if info.type == "file" and item:match("%.lua$") then
                files[#files + 1] = itemRel
            elseif info.type == "directory" then
                local sub = collectFiles(basePath, itemRel)
                for _, sf in ipairs(sub) do
                    files[#files + 1] = sf
                end
            end
        end
    end
    return files
end

-- ============================================================
-- Recursive directory removal (save-directory files only)
-- ============================================================
local function rmDir(path)
    local ok2, items = pcall(love.filesystem.getDirectoryItems, path)
    if not ok2 or not items then return end
    for _, item in ipairs(items) do
        local fp = path .. "/" .. item
        local info = love.filesystem.getInfo(fp)
        if info then
            if info.type == "directory" then
                rmDir(fp)
            end
            love.filesystem.remove(fp)
        end
    end
    love.filesystem.remove(path)
end

-- ============================================================
-- List available export packages in save/exports/
-- ============================================================
function Packager.listExports()
    Packager.ensureDirs()
    local exports = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, Config.EXPORTS_DIR)
    if not ok or not items then return exports end

    for _, item in ipairs(items) do
        if item:match("%.cart%.lua$") then
            local path = Config.EXPORTS_DIR .. "/" .. item
            local info = love.filesystem.getInfo(path)
            exports[#exports + 1] = {
                path     = path,
                filename = item,
                modtime  = info and info.modtime or 0,
            }
        end
    end
    table.sort(exports, function(a, b) return a.modtime > b.modtime end)
    return exports
end

-- ============================================================
-- Export a cartridge to a .cart.lua package
-- opts.withSaveOverrides: also include save/carts/<id>/ overrides
-- ============================================================
function Packager.exportCart(cartId, opts)
    opts = opts or {}
    Packager.ensureDirs()

    local srcDir  = Config.CARTS_DIR .. "/" .. cartId
    local saveDir = Config.CART_SAVE_DIR .. "/" .. cartId

    -- Verify source exists
    local info = love.filesystem.getInfo(srcDir)
    if not info then
        return { ok = false, err = "Cart not found: " .. cartId }
    end

    -- Collect source files
    local fileList = collectFiles(srcDir, "")
    if #fileList == 0 then
        return { ok = false, err = "No files in cart" }
    end

    -- Read all source files
    local files = {}
    for _, relPath in ipairs(fileList) do
        local text = Packager.readText(srcDir .. "/" .. relPath)
        if text then
            files[relPath] = text
        end
    end

    -- Validate required files
    if not files["cart.lua"] then
        return { ok = false, err = "Missing cart.lua" }
    end
    if not files["main.lua"] then
        return { ok = false, err = "Missing main.lua" }
    end

    -- Apply save overrides if requested
    if opts.withSaveOverrides then
        local saveContent = Packager.readText(saveDir .. "/content.lua")
        if saveContent then
            files["content.lua"] = saveContent
        end
        local saveLevels = collectFiles(saveDir, "levels")
        for _, relPath in ipairs(saveLevels) do
            local text = Packager.readText(saveDir .. "/" .. relPath)
            if text then
                files[relPath] = text
            end
        end
    end

    -- Load metadata from cart.lua for the package header
    local Serialize = require("src.util.serialize")
    local meta = Serialize.load(srcDir .. "/cart.lua") or {}

    -- Build the package Lua source
    local parts = {}
    parts[#parts + 1] = "return {\n"
    parts[#parts + 1] = "packageVersion = 1,\n"
    parts[#parts + 1] = string.format("createdAt = %d,\n", os.time())
    parts[#parts + 1] = "meta = {\n"
    parts[#parts + 1] = string.format("  id = %q,\n", Packager.sanitizeId(meta.id or meta.name or cartId))
    parts[#parts + 1] = string.format("  name = %q,\n", meta.name or cartId)
    parts[#parts + 1] = string.format("  version = %q,\n", meta.version or "1.0")
    parts[#parts + 1] = string.format("  author = %q,\n", meta.author or "Unknown")
    parts[#parts + 1] = string.format("  description = %q,\n", meta.description or "")
    parts[#parts + 1] = "},\n"
    parts[#parts + 1] = "files = {\n"

    -- Sort keys for deterministic output
    local sortedKeys = {}
    for k in pairs(files) do sortedKeys[#sortedKeys + 1] = k end
    table.sort(sortedKeys)

    for _, filename in ipairs(sortedKeys) do
        parts[#parts + 1] = string.format("[%q] = %s,\n", filename, quoteLongString(files[filename]))
    end

    parts[#parts + 1] = "},\n"
    parts[#parts + 1] = "}\n"

    local packageStr = table.concat(parts)

    -- Write to exports directory
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local outName = cartId .. "_" .. timestamp .. ".cart.lua"
    local outPath = Config.EXPORTS_DIR .. "/" .. outName

    local wOk, wErr = Packager.writeText(outPath, packageStr)
    if not wOk then
        return { ok = false, err = "Write failed: " .. tostring(wErr) }
    end

    return { ok = true, outPath = outPath, filename = outName }
end

-- ============================================================
-- Import a .cart.lua package and install as a new cartridge
-- ============================================================
function Packager.importCart(packagePath)
    -- Read package file
    local data = Packager.readText(packagePath)
    if not data then
        return { ok = false, err = "Cannot read package" }
    end

    -- Parse in sandboxed environment (no globals available)
    local fn, lerr
    if setfenv then
        fn, lerr = loadstring(data)
        if fn then setfenv(fn, {}) end
    else
        fn, lerr = load(data, "package", "t", {})
    end
    if not fn then
        return { ok = false, err = "Parse error" }
    end

    local ok, pkg = pcall(fn)
    if not ok then
        return { ok = false, err = "Load error" }
    end

    -- Validate package schema
    if type(pkg) ~= "table" then
        return { ok = false, err = "Invalid package format" }
    end
    if not pkg.files or type(pkg.files) ~= "table" then
        return { ok = false, err = "No files in package" }
    end
    if not pkg.files["cart.lua"] then
        return { ok = false, err = "Missing cart.lua" }
    end
    if not pkg.files["main.lua"] then
        return { ok = false, err = "Missing main.lua" }
    end

    -- Determine install ID
    local baseId
    if pkg.meta and pkg.meta.id then
        baseId = Packager.sanitizeId(pkg.meta.id)
    elseif pkg.meta and pkg.meta.name then
        baseId = Packager.sanitizeId(pkg.meta.name)
    else
        baseId = "imported_cart"
    end

    -- Ensure unique ID
    local CartManager = require("src.os.cart_manager")
    local existingIds = CartManager.getCartIds()
    local installId = Packager.uniqueId(baseId, existingIds)

    -- Install files
    local installDir = Config.CARTS_DIR .. "/" .. installId
    love.filesystem.createDirectory(installDir)

    for filename, content in pairs(pkg.files) do
        -- Safety: reject path traversal
        if filename:match("%.%.") then
            print("[PACKAGER] Skipping suspicious path: " .. filename)
        else
            local filePath = installDir .. "/" .. filename
            local wOk, wErr = Packager.writeText(filePath, content)
            if not wOk then
                return { ok = false, err = "Write failed: " .. filename }
            end
        end
    end

    return { ok = true, cartId = installId }
end

-- ============================================================
-- Duplicate a cartridge source into a new ID
-- ============================================================
function Packager.duplicateCart(cartId)
    local srcDir = Config.CARTS_DIR .. "/" .. cartId

    -- Collect and read all source files
    local fileList = collectFiles(srcDir, "")
    if #fileList == 0 then
        return { ok = false, err = "No files to copy" }
    end

    local files = {}
    for _, relPath in ipairs(fileList) do
        local text = Packager.readText(srcDir .. "/" .. relPath)
        if text then
            files[relPath] = text
        end
    end

    -- Determine new unique ID
    local CartManager = require("src.os.cart_manager")
    local existingIds = CartManager.getCartIds()
    local newId = Packager.uniqueId(cartId, existingIds)

    -- Write to new directory
    local destDir = Config.CARTS_DIR .. "/" .. newId
    love.filesystem.createDirectory(destDir)

    for filename, content in pairs(files) do
        local wOk, wErr = Packager.writeText(destDir .. "/" .. filename, content)
        if not wOk then
            return { ok = false, err = "Write failed: " .. filename }
        end
    end

    return { ok = true, cartId = newId }
end

-- ============================================================
-- Delete a cartridge (removes save-dir copies; source-dir carts
-- cannot be removed by LOVE's filesystem)
-- ============================================================
function Packager.deleteCart(cartId)
    local cartDir = Config.CARTS_DIR .. "/" .. cartId
    local saveDir = Config.CART_SAVE_DIR .. "/" .. cartId

    rmDir(cartDir)
    rmDir(saveDir)

    -- Check if cart directory still visible (source-only cart)
    local info = love.filesystem.getInfo(cartDir)
    if info then
        return { ok = false, err = "SOURCE CART: REMOVE FROM PROJECT" }
    end

    return { ok = true }
end

return Packager
