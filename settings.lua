-- /home/sheldi/Documents/lua/love2d/MiniCraft/settings.lua
local SettingsMenu = {}

SettingsMenu.buttons = {}
SettingsMenu.settings = {}

local screenWidth = 0
local screenHeight = 0
local buttonWidth = 200
local buttonHeight = 50
local settingItemHeight = 40

function SettingsMenu:load()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    -- Example settings
    self.settings = {
        { name = "Fullscreen", value = love.window.getFullscreen(), type = "toggle", y_offset = 150 },
        { name = "View Distance", value = 10, type = "number", y_offset = 150 + settingItemHeight },
        { name = "Music Volume", value = 0.8, type = "slider", y_offset = 150 + settingItemHeight * 2},
        -- Keybinds would be more complex, placeholder for now
        { name = "Keybinds", value = "Edit...", type = "button", y_offset = 150 + settingItemHeight * 3}
    }

    table.insert(self.settings, {
        name = "Mobile Controls",
        value = isMobile,
        type = "toggle",
        y_offset = 150 + settingItemHeight * 4
    })

    self.buttons = {
        {
            text = "Back",
            x = screenWidth / 2 - buttonWidth / 2,
            y = screenHeight - buttonHeight - 50,
            width = buttonWidth,
            height = buttonHeight,
            action = function() switchGameState("menu") end
        }
        -- Potentially a "Save" or "Apply" button if settings aren't applied immediately
    }
    self.titleFont = love.graphics.newFont(36)
    self.settingFont = love.graphics.newFont(20)
    self.buttonFont = love.graphics.newFont(24)

    -- Initialize UI elements for settings (e.g., checkbox rects)
    for i, setting in ipairs(self.settings) do
        setting.label_x = 50
        setting.value_x = screenWidth / 2
        setting.y = setting.y_offset
        if setting.type == "toggle" then
            setting.ui_x = setting.value_x
            setting.ui_y = setting.y
            setting.ui_width = 25
            setting.ui_height = 25
        elseif setting.type == "slider" then
            setting.slider_x = setting.value_x
            setting.slider_y = setting.y + 10
            setting.slider_width = 200
            setting.slider_height = 10
            setting.slider_knob_width = 20
        end
    end
end

function SettingsMenu:update(dt)
    -- Handle dragging sliders, etc.
end

function SettingsMenu:draw()
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("Settings", 0, 50, screenWidth, "center")

    love.graphics.setFont(self.settingFont)
    for _, setting in ipairs(self.settings) do
        love.graphics.setColor(1,1,1)
        love.graphics.printf(setting.name .. ":", setting.label_x, setting.y + 5, screenWidth, "left")
        if setting.type == "toggle" then
            love.graphics.rectangle("line", setting.ui_x, setting.ui_y, setting.ui_width, setting.ui_height)
            if setting.value then
                love.graphics.setLineWidth(2)
                love.graphics.line(setting.ui_x + 3, setting.ui_y + setting.ui_height/2, setting.ui_x + setting.ui_width/2, setting.ui_y + setting.ui_height - 3)
                love.graphics.line(setting.ui_x + setting.ui_width/2, setting.ui_y + setting.ui_height - 3, setting.ui_x + setting.ui_width - 3, setting.ui_y + 3)
                love.graphics.setLineWidth(1)
            end
        elseif setting.type == "number" then
            love.graphics.printf(tostring(setting.value), setting.value_x, setting.y + 5, screenWidth, "left")
        elseif setting.type == "slider" then
            love.graphics.setColor(0.5,0.5,0.5)
            love.graphics.rectangle("fill", setting.slider_x, setting.slider_y, setting.slider_width, setting.slider_height)
            love.graphics.setColor(0.8,0.8,0.8)
            local knob_x = setting.slider_x + setting.value * setting.slider_width - (setting.slider_knob_width/2)
            knob_x = math.max(setting.slider_x, math.min(knob_x, setting.slider_x + setting.slider_width - setting.slider_knob_width))
            love.graphics.rectangle("fill", knob_x, setting.slider_y - 5, setting.slider_knob_width, setting.slider_height + 10)
        elseif setting.type == "button" then
            love.graphics.setColor(0.6,0.6,0.6)
            love.graphics.rectangle("fill", setting.value_x, setting.y, 100, 30)
            love.graphics.setColor(0,0,0)
            love.graphics.printf(setting.value, setting.value_x, setting.y + 15 - self.settingFont:getHeight()/2, 100, "center")
        end
    end
    love.graphics.setColor(1,1,1)

    love.graphics.setFont(self.buttonFont)
    for _, button in ipairs(self.buttons) do
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(button.text, button.x, button.y + button.height / 2 - self.buttonFont:getHeight() / 2, button.width, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function SettingsMenu:mousepressed(x, y, btn)
    if btn == 1 then
        for _, button in ipairs(self.buttons) do
            if x >= button.x and x <= button.x + button.width and
               y >= button.y and y <= button.y + button.height then
                if button.action then
                    button.action()
                    return true
                end
            end
        end

        for _, setting in ipairs(self.settings) do
            if setting.type == "toggle" then
                if x >= setting.ui_x and x <= setting.ui_x + setting.ui_width and
                   y >= setting.ui_y and y <= setting.ui_y + setting.ui_height then
                    setting.value = not setting.value
                    if setting.name == "Fullscreen" then
                        local currentFullscreen, fstype = love.window.getFullscreen()
                        love.window.setFullscreen(not currentFullscreen, fstype)
                        setting.value = love.window.getFullscreen() -- Update with actual state
                    elseif setting.name == "Mobile Controls" then
                        isMobile = setting.value
                        print("Mobile Controls toggled to " .. tostring(setting.value))
                    end
                    -- TODO: Save settings persistently
                    print(setting.name .. " toggled to " .. tostring(setting.value))
                    return true
                end
            elseif setting.type == "button" and setting.name == "Keybinds" then
                 if x >= setting.value_x and x <= setting.value_x + 100 and
                    y >= setting.y and y <= setting.y + 30 then
                    switchGameState("keybind_settings") -- Switch to keybind settings screen
                    return true
                 end
            end
        end
    end
    return false
end

function SettingsMenu:resize(w, h)
    self:load()
end

return SettingsMenu
