_G.love = _G.love or require("love")

-------------------------------------------------------------------------
-- 2D version of 'Minecraft' game called 'Minicraft'
-- by "Sheldanim8ions"
-------------------------------------------------------------------------

-- Global game state and modules
gameState = nil -- Initial state will be set in love.load
mainMenu = nil
settingsMenu = nil
worldSelectMenu = nil
game = nil -- This will be the existing game module
keybindSettings = nil -- New keybind settings module

-- Global function to switch game states
function switchGameState(newState, ...)
    if gameState == newState and newState ~= "game" then -- Allow re-entering game state if needed for reload
        -- If modules have a 'reload' or 'refresh' method, call it.
        -- For now, just print a message or do nothing if same state (except game)
        -- print("Already in state: " .. newState)
        -- return
    end
    print("Switching state from " .. (gameState or "nil") .. " to " .. newState)

    -- Deactivate text input if it was active, unless the new state reactivates it
    if love.keyboard.hasTextInput() then
        love.keyboard.setTextInput(false)
    end

    local previousState = gameState
    gameState = newState
    local args = {...}

    -- Call leave functions for previous state if they exist
    if previousState == "world_select" and worldSelectMenu and worldSelectMenu.leave then
        worldSelectMenu:leave()
    end

    if newState == "menu" then
        if not mainMenu then mainMenu = require("menu") end
        mainMenu:load() -- Or an :enter() function
    elseif newState == "settings" then
        if not settingsMenu then settingsMenu = require("settings") end
        settingsMenu:load()
    elseif newState == "world_select" then
        if not worldSelectMenu then worldSelectMenu = require("world_select") end
        worldSelectMenu:load()
    elseif newState == "game" then
        if not game then game = require("game") end -- Ensure game module is loaded
        local worldDataArgument = select(1, ...) -- Get the first argument passed (the world data)

        if game.enterState then
            game.enterState(worldDataArgument) -- Correctly call enterState
        else
            print("ERROR: game.enterState function not found!")
            -- Handle this critical error, perhaps switch to an error state or menu
        end
    elseif newState == "keybind_settings" then
        if not keybindSettings then keybindSettings = require("keybind_settings") end
        keybindSettings:load()
    end
end

function love.load()
    -- Attempt to set permissions on the "worlds" directory (Linux only)
    if love.system.getOS() == "Linux" then
        -- This will only work if the game is run with sufficient privileges
        os.execute("chmod -R 777 worlds/")
    end

    love.graphics.setBackgroundColor(0.15, 0.15, 0.2) -- Darker background

    -- Set the game's identity. This is crucial for save files.
    -- It creates a unique save directory for your game.
    love.filesystem.setIdentity("Minicraft") -- Correctly set the filesystem identity

    print("Save directory: " .. love.filesystem.getSaveDirectory())

    -- Load the core game logic module
    game = require("game")
    if game.preload then
        game.preload()
    end

    -- Initialize and switch to the initial game state
    switchGameState("menu")
end

function love.update(dt)
    -- Ensure the game module's update function is called
    if game and game.update then
        game.update(dt)
    else
        print("Error: game.update is not defined.")
    end

    if gameState == "menu" and mainMenu then
        mainMenu:update(dt)
    elseif gameState == "settings" and settingsMenu then
        settingsMenu:update(dt)
    elseif gameState == "world_select" and worldSelectMenu then
        worldSelectMenu:update(dt)
    elseif gameState == "keybind_settings" then
        if keybindSettings and keybindSettings.update then
            keybindSettings:update(dt)
        else
            print("Error: keybindSettings.update is not defined.")
        end
    end
end

function love.draw()
    if gameState == "menu" and mainMenu then mainMenu:draw()
    elseif gameState == "settings" and settingsMenu then settingsMenu:draw()
    elseif gameState == "world_select" and worldSelectMenu then worldSelectMenu:draw()
    elseif gameState == "game" and game then game.draw()
    elseif gameState == "keybind_settings" and keybindSettings then keybindSettings:draw()
    else
        love.graphics.print("Error: Unknown or uninitialized game state: " .. tostring(gameState), 50, 50)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if gameState == "menu" and mainMenu and mainMenu.keypressed then if mainMenu:keypressed(key, scancode, isrepeat) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.keypressed then if settingsMenu:keypressed(key, scancode, isrepeat) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.keypressed then if worldSelectMenu:keypressed(key, scancode, isrepeat) then return end
    elseif gameState == "game" and game and game.keypressed then game.keypressed(key, scancode, isrepeat)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.keypressed then keybindSettings:keypressed(key, scancode, isrepeat)
    end
end

function love.keyreleased(key, scancode)
    if gameState == "menu" and mainMenu and mainMenu.keyreleased then if mainMenu:keyreleased(key, scancode) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.keyreleased then if settingsMenu:keyreleased(key, scancode) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.keyreleased then if worldSelectMenu:keyreleased(key, scancode) then return end
    elseif gameState == "game" and game and game.keyreleased then game.keyreleased(key, scancode)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.keyreleased then keybindSettings:keyreleased(key, scancode)
    end
end
-- Pass other love callbacks similarly if your states need them:
-- love.mousepressed, love.mousereleased, love.mousemoved, love.wheelmoved, love.textinput, love.resize

function love.mousepressed(x, y, button, istouch, presses)
    if gameState == "menu" and mainMenu and mainMenu.mousepressed then if mainMenu:mousepressed(x, y, button, istouch, presses) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.mousepressed then if settingsMenu:mousepressed(x, y, button, istouch, presses) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.mousepressed then if worldSelectMenu:mousepressed(x, y, button, istouch, presses) then return end
    elseif gameState == "game" and game and game.mousepressed then game.mousepressed(x, y, button, istouch, presses)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.mousepressed then keybindSettings:mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if gameState == "menu" and mainMenu and mainMenu.mousereleased then if mainMenu:mousereleased(x, y, button, istouch, presses) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.mousereleased then if settingsMenu:mousereleased(x, y, button, istouch, presses) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.mousereleased then if worldSelectMenu:mousereleased(x, y, button, istouch, presses) then return end
    elseif gameState == "game" and game and game.mousereleased then game.mousereleased(x, y, button, istouch, presses)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.mousereleased then keybindSettings:mousereleased(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if gameState == "menu" and mainMenu and mainMenu.mousemoved then if mainMenu:mousemoved(x, y, dx, dy, istouch) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.mousemoved then if settingsMenu:mousemoved(x, y, dx, dy, istouch) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.mousemoved then if worldSelectMenu:mousemoved(x, y, dx, dy, istouch) then return end
    elseif gameState == "game" and game and game.mousemoved then game.mousemoved(x, y, dx, dy, istouch)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.mousemoved then keybindSettings:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.wheelmoved(dx, dy) -- LÖVE 11+ syntax
    if gameState == "menu" and mainMenu and mainMenu.wheelmoved then if mainMenu:wheelmoved(dx, dy) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.wheelmoved then if settingsMenu:wheelmoved(dx, dy) then return end
    elseif gameState == "world_select" and worldSelectMenu and worldSelectMenu.wheelmoved then if worldSelectMenu:wheelmoved(dx, dy) then return end
    elseif gameState == "game" and game and game.wheelmoved then game.wheelmoved(dx, dy)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.wheelmoved then keybindSettings:wheelmoved(dx, dy)
    end
end

function love.textinput(text)
    if gameState == "world_select" and worldSelectMenu and worldSelectMenu.textinput then if worldSelectMenu:textinput(text) then return end
    elseif gameState == "settings" and settingsMenu and settingsMenu.textinput then if settingsMenu:textinput(text) then return end
    -- Add for other states if they need text input
    elseif gameState == "game" and game and game.textinput then game.textinput(text)
    elseif gameState == "keybind_settings" and keybindSettings and keybindSettings.textinput then keybindSettings:textinput(text)
    end
end

function love.resize(w, h)
    if mainMenu and mainMenu.resize then mainMenu:resize(w,h) end
    if settingsMenu and settingsMenu.resize then settingsMenu:resize(w,h) end
    if worldSelectMenu and worldSelectMenu.resize then worldSelectMenu:resize(w,h) end
    if game and game.resize then game.resize(w,h) end
    if keybindSettings and keybindSettings.resize then keybindSettings:resize(w,h) end
end