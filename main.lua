-- main.lua  Fantasy Console (Atari 2600 style)
-- Thin entry point: delegates everything to src/app.lua

local App = require("src.app")

function love.load()
    App.load()
end

function love.update(dt)
    App.update(dt)
end

function love.draw()
    App.draw()
    App.endFrame()
end

function love.keypressed(key)
    App.keypressed(key)
end

function love.keyreleased(key)
    App.keyreleased(key)
end

function love.mousepressed(x, y, button)
    App.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    App.mousereleased(x, y, button)
end

function love.resize(w, h)
    App.resize(w, h)
end
