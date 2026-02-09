-- cartridges/demo_platformer/main.lua
-- Cart runtime wrapper for the built-in demo platformer.
-- External cartridges would implement their own game logic here
-- using the engine API table passed to Cart.load().
local DemoGame = require("src.game.demo_game")

local Cart = {}

function Cart.load(api)
    DemoGame.init()
end

function Cart.update(dt)
    DemoGame.update(dt)
end

function Cart.draw()
    DemoGame.draw()
end

function Cart.keypressed(key)
    DemoGame.keypressed(key)
end

function Cart.unload()
    DemoGame.shutdown()
end

return Cart
