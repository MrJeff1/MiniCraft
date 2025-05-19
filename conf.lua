-- lua config file

function love.conf(t)
    t.window.title = "Minicraft"
    t.window.width = 800
    t.window.height = 600
    t.window.fullscreen = false
    t.window.resizable = true
    t.window.vsync = true
    t.window.fullscreenType = "desktop" -- Use "desktop" for borderless fullscreen
end
