_G.love = _G.love or require("love")

-- /home/sheldi/Documents/lua/love2d/MiniCraft/menu.lua
local MainMenu = {}

MainMenu.buttons = {}

local screenWidth = 0
local screenHeight = 0
local buttonWidth = 220
local buttonHeight = 50
local buttonSpacing = 25
local titleOffsetY = 0 -- Will be calculated

-- Add keybinds table and editing state
local keybinds = {
    jump = "space",
    left = "a",
    right = "d",
    inventory = "e",
    pause = "escape"
}
local editingKey = nil -- nil or the action being edited
local settingsButtons = {}

-- Add volume controls
local musicVolume = 1.0
local sfxVolume = 1.0
local volumeButtons = {}
local editingVolume = nil -- "music" or "sfx" if being edited

-- Reference to game for volume control
local game = require("game")

function MainMenu:load()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
    titleOffsetY = screenHeight / 3.5

    -- Set initial volumes from game module
    musicVolume = game.getMusicVolume and game.getMusicVolume() or 1.0
    sfxVolume = game.getSfxVolume and game.getSfxVolume() or 1.0

    self.buttons = {
        {
            text = "Play",
            x = screenWidth / 2 - buttonWidth / 2,
            y = titleOffsetY + 80,
            width = buttonWidth,
            height = buttonHeight,
            action = function() switchGameState("world_select") end
        },
        {
            text = "Settings",
            x = screenWidth / 2 - buttonWidth / 2,
            y = titleOffsetY + 80 + buttonHeight + buttonSpacing,
            width = buttonWidth,
            height = buttonHeight,
            action = function() switchGameState("settings") end
        },
        {
            text = "Quit",
            x = screenWidth / 2 - buttonWidth / 2,
            y = titleOffsetY + 80 + (buttonHeight + buttonSpacing) * 2,
            width = buttonWidth,
            height = buttonHeight,
            action = function() love.event.quit() end
        }
    }
    self.titleFont = love.graphics.newFont(48)
    self.buttonFont = love.graphics.newFont(28)

    -- Add settings buttons for keybinds
    settingsButtons = {}
    local settingsY = titleOffsetY + 80
    local i = 0
    for action, key in pairs(keybinds) do
        table.insert(settingsButtons, {
            action = action,
            key = key,
            x = screenWidth / 2 - buttonWidth / 2,
            y = settingsY + (buttonHeight + buttonSpacing) * i,
            width = buttonWidth,
            height = buttonHeight,
        })
        i = i + 1
    end

    -- Volume controls for settings
    local vBtnW, vBtnH = 220, 50
    local vSpacing = 25
    volumeButtons = {
        {
            label = "Music Volume",
            type = "music",
            x = screenWidth / 2 - vBtnW / 2,
            y = settingsY + (#settingsButtons + 0) * (vBtnH + vSpacing),
            width = vBtnW,
            height = vBtnH,
        },
        {
            label = "SFX Volume",
            type = "sfx",
            x = screenWidth / 2 - vBtnW / 2,
            y = settingsY + (#settingsButtons + 1) * (vBtnH + vSpacing),
            width = vBtnW,
            height = vBtnH,
        }
    }

    -- Play background music if available
    if game and game.bgMusic and not game.bgMusic:isPlaying() then
        game.bgMusic:play()
    end
end

function MainMenu:update(dt)
    -- Play background music if not already playing
    if game and game.bgMusic and not game.bgMusic:isPlaying() then
        game.bgMusic:play()
    end
    -- For hover effects or animations later
end

-- Add a dummy update for keybind settings to avoid errors
function MainMenu:updateSettings(dt)
    -- No-op for now; add logic here if you want animated settings UI
end

function MainMenu:draw()
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("Minicraft", 0, titleOffsetY, screenWidth, "center")

    love.graphics.setFont(self.buttonFont)
    for _, button in ipairs(self.buttons) do
        local mx, my = love.mouse.getPosition()
        if mx >= button.x and mx <= button.x + button.width and
           my >= button.y and my <= button.y + button.height then
            love.graphics.setColor(0.85, 0.85, 0.85) -- Hover color
        else
            love.graphics.setColor(0.7, 0.7, 0.7) -- Default color
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5) -- Rounded corners
        love.graphics.setColor(0, 0, 0) -- Text color
        love.graphics.printf(button.text, button.x, button.y + button.height / 2 - self.buttonFont:getHeight() / 2, button.width, "center")
    end
    love.graphics.setColor(1, 1, 1) -- Reset color
end

function MainMenu:drawSettings()
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("Settings", 0, titleOffsetY, screenWidth, "center")
    love.graphics.setFont(self.buttonFont)
    for _, btn in ipairs(settingsButtons) do
        if editingKey == btn.action then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 5, 5)
        love.graphics.setColor(0, 0, 0)
        local label = btn.action:sub(1,1):upper()..btn.action:sub(2) .. ": " .. btn.key
        if editingKey == btn.action then
            label = label .. " (press new key)"
        end
        love.graphics.printf(label, btn.x, btn.y + btn.height / 2 - self.buttonFont:getHeight() / 2, btn.width, "center")
    end

    -- Draw volume controls
    for _, vbtn in ipairs(volumeButtons) do
        if editingVolume == vbtn.type then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end
        love.graphics.rectangle("fill", vbtn.x, vbtn.y, vbtn.width, vbtn.height, 5, 5)
        love.graphics.setColor(0, 0, 0)
        local value = vbtn.type == "music" and (math.floor((musicVolume or 1) * 100)) or (math.floor((sfxVolume or 1) * 100))
        local label = vbtn.label .. ": " .. value .. "%"
        if editingVolume == vbtn.type then
            label = label .. " (←/→ to adjust, Enter to finish)"
        end
        love.graphics.printf(label, vbtn.x, vbtn.y + vbtn.height / 2 - self.buttonFont:getHeight() / 2, vbtn.width, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function MainMenu:mousepressed(x, y, btn)
    if btn == 1 then -- Left mouse button
        for _, button in ipairs(self.buttons) do
            if x >= button.x and x <= button.x + button.width and
               y >= button.y and y <= button.y + button.height then
                if button.action then
                    button.action()
                    return true -- Event handled
                end
            end
        end
    end

    -- If in settings, handle keybind buttons
    if getCurrentState and getCurrentState() == "settings" and btn == 1 then
        for _, sb in ipairs(settingsButtons) do
            if x >= sb.x and x <= sb.x + sb.width and y >= sb.y and y <= sb.y + sb.height then
                editingKey = sb.action
                return true
            end
        end

        -- Volume controls in settings
        for _, vbtn in ipairs(volumeButtons) do
            if x >= vbtn.x and x <= vbtn.x + vbtn.width and y >= vbtn.y and y <= vbtn.y + vbtn.height then
                editingVolume = vbtn.type
                return true
            end
        end
    end

    return false -- Event not handled
end

function MainMenu:keypressed(key)
    if getCurrentState and getCurrentState() == "settings" and editingKey then
        -- Prevent duplicate keybinds
        for action, k in pairs(keybinds) do
            if k == key then
                keybinds[action] = ""
            end
        end
        keybinds[editingKey] = key
        -- Update settingsButtons to reflect new key
        for _, sb in ipairs(settingsButtons) do
            if sb.action == editingKey then
                sb.key = key
            end
        end
        editingKey = nil
        return true
    end

    if getCurrentState and getCurrentState() == "settings" and editingVolume then
        if key == "left" then
            if editingVolume == "music" then
                musicVolume = math.max(0, musicVolume - 0.05)
                if game and game.setMusicVolume then game.setMusicVolume(musicVolume) end
            elseif editingVolume == "sfx" then
                sfxVolume = math.max(0, sfxVolume - 0.05)
                if game and game.setSfxVolume then game.setSfxVolume(sfxVolume) end
            end
        elseif key == "right" then
            if editingVolume == "music" then
                musicVolume = math.min(1, musicVolume + 0.05)
                if game and game.setMusicVolume then game.setMusicVolume(musicVolume) end
            elseif editingVolume == "sfx" then
                sfxVolume = math.min(1, sfxVolume + 0.05)
                if game and game.setSfxVolume then game.setSfxVolume(sfxVolume) end
            end
        elseif key == "return" or key == "kpenter" or key == "escape" then
            editingVolume = nil
        end
        return true
    end

    return false
end

function MainMenu:getKeybinds()
    return keybinds
end

function MainMenu:getMusicVolume()
    return musicVolume
end

function MainMenu:getSfxVolume()
    return sfxVolume
end

function MainMenu:resize(w, h)
    -- Recalculate positions if window is resized
    screenWidth = w
    screenHeight = h
    titleOffsetY = screenHeight / 3.5
    self:load()
end

return MainMenu
