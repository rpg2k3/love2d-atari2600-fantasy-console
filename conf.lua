-- conf.lua  Fantasy Console (Atari 2600 style)
-- LOVE 11.5 configuration

function love.conf(t)
    t.identity = "fantasyconsole2600"
    t.version  = "11.5"

    t.window.title  = "Fantasy Console  -  Atari 2600"
    t.window.width  = 960
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth  = 320
    t.window.minheight = 240
    t.window.vsync = 1

    t.modules.joystick = true
    t.modules.physics  = false
    t.modules.video    = false

    t.console = false
end
