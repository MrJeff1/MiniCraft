local KeybindSettings = {}

KeybindSettings.keybinds = {
    { action = "Move Up", key = "w" },
    { action = "Move Down", key = "s" },
    { action = "Move Left", key = "a" },
    { action = "Move Right", key = "d" },
    { action = "Attack", key = "space" }
}

local selectedKeybind = nil
local screenWidth, screenHeight

function KeybindSettings:load()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
end

function KeybindSettings:draw()
    love.graphics.printf("Keybind Settings", 0, 50, screenWidth, "center")
    local y = 150
    for i, keybind in ipairs(self.keybinds) do
        love.graphics.printf(keybind.action, 100, y, screenWidth, "left")
        love.graphics.printf(keybind.key, screenWidth - 200, y, screenWidth, "right")
        y = y + 40
    end
    love.graphics.printf("Press ESC to go back", 0, screenHeight - 50, screenWidth, "center")
end

function KeybindSettings:keypressed(key)
    if selectedKeybind then
        self.keybinds[selectedKeybind].key = key
        selectedKeybind = nil
    elseif key == "escape" then
        switchGameState("settings") -- Go back to settings menu
    end
end

function KeybindSettings:mousepressed(x, y, btn)
    if btn == 1 then
        local y = 150
        for i, keybind in ipairs(self.keybinds) do
            if y <= y + 30 and y + 30 >= y then
                selectedKeybind = i
                return
            end
            y = y + 40
        end
    end
end

return KeybindSettings
