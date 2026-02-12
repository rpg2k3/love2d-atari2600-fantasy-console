-- src/config.lua  Global constants and resolution presets
local Config = {}

-- Internal resolution presets (all 4:3 or classic TV ratios)
Config.RES_PRESETS = {
    { w = 160, h = 192, label = "160x192 (2600)" },      -- true Atari 2600
    { w = 192, h = 224, label = "192x224 (Arcade)" },     -- arcade-ish
    { w = 320, h = 240, label = "320x240 (Hi-res)" },     -- higher res retro
}
Config.RES_INDEX = 1  -- default preset index

-- CRT intensity presets
Config.CRT_PRESETS = {
    { label = "OFF",    intensity = 0.0  },
    { label = "Subtle", intensity = 0.45 },
    { label = "Strong", intensity = 1.0  },
}
Config.CRT_INDEX = 2  -- default: subtle

-- Aspect ratio (strict 4:3)
Config.ASPECT_W = 4
Config.ASPECT_H = 3

-- Max sprite/tile palette colors
Config.MAX_SPRITE_COLORS = 4   -- per sprite (Atari-ish constraint)
Config.MAX_TILE_COLORS   = 4

-- Sprite / tile grid sizes
Config.SPRITE_W = 8
Config.SPRITE_H = 8
Config.TILE_W   = 8
Config.TILE_H   = 8

-- Tilemap defaults
Config.MAP_COLS = 32
Config.MAP_ROWS = 24

-- Audio
Config.SAMPLE_RATE = 22050
Config.BIT_DEPTH   = 16

-- App modes
Config.MODE_BOOT   = "boot"
Config.MODE_CART   = "cart"
Config.MODE_GAME   = "game"     -- used internally by demo_game
Config.MODE_EDITOR = "editor"

-- Debug
Config.DEBUG_OVERLAY = false
Config.SHOW_HELP     = false
Config.GAMEPAD_DEBUG = false

-- Gamepad
Config.STICK_DEADZONE = 0.4

-- Level paths
Config.LEVELS_DIR     = "save/levels"
Config.DEFAULT_LEVEL  = "LEVEL_01"
Config.LEVEL_VERSION  = 1

-- Undo
Config.MAX_UNDO = 40

-- Cartridge system
Config.CARTS_DIR          = "cartridges"
Config.CART_SAVE_DIR      = "save/carts"
Config.DEFAULT_LEVELS_DIR = "save/levels"
Config.CONTENT_SAVE_PATH  = "save/content.lua"
Config.EXPORTS_DIR        = "save/exports"

-- System settings persistence
Config.SYSTEM_DIR         = "save/system"
Config.SETTINGS_PATH      = "save/system/settings.lua"

-- OS states
Config.MODE_SPLASH    = "splash"
Config.MODE_INSERTING = "inserting"

return Config
