_G.love = _G.love or require("love")

-- Remove or comment out this block to avoid circular require:
-- local MainMenu = nil
-- pcall(function() MainMenu = require("menu") end)

local function getCurrentState()
    if isPaused and pauseMenuOptions[selectedPauseOption] == "Settings" then
        return "settings"
    end
    -- You can expand this if you have more states
    return nil
end

local game = {}
local blockColor = require("blockColor")

local currentWorldData = nil -- To store the loaded world's data

-- Global game settings
local width -- Declare at file scope, initialize in game.load()
local height -- Declare at file scope, initialize in game.load()
local BLOCK_SIZE = 50 -- Define a global block size for consistency
local WORLD_WIDTH_BLOCKS = 200 -- Define world width in blocks
local NUM_STONE_LAYERS = 56 -- Define how many layers of stone to generate below dirt
local worldPixelWidth -- To be calculated in load

-- Volume settings (0.0 to 1.0)
local musicVolume = 1.0
local sfxVolume = 0.75

-- Game state variables (implicitly global, common in simple Love2D games)
local player -- Will be initialized in game.enterState()
local blocks -- Will be initialized in game.enterState()
local cursor -- Will be initialized in game.enterState()
local camera = { x = 0, y = 0 }
local currentWorldName = "NewWorld" -- Default world
local currentWorldType = "default"
local currentWorldSeed = tostring(os.time())
local currentWorldVersion = 1.0
local commandMenuOpen = false -- Flag to track if command menu is open
local commandInput = ""       -- String to store typed command
local currentGameMode = "creative" -- "creative" or "survival"

local worldGen = {}
-- Ore generation chances
local COAL_ORE_CHANCE = 0.05 -- 5% chance for coal ore in a stone layer spot
local IRON_ORE_CHANCE = 0.03 -- 3% chance for iron ore in a stone layer spot

local availableBlockTypes = {"dirt", "stone", "wood", "grass", "log", "leaves", "coal_ore", "iron_ore"}
local currentBlockTypeIndex = 1
local selectedBlockType = availableBlockTypes[currentBlockTypeIndex] or availableBlockTypes[1]

-- Game state for file selection
local isSelectingFile = false
local availableWorldFiles = {}
local selectedFileIndex = 1

-- Mobile support variables
local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local debugMobileControls = false -- Allow PC users to enable mobile controls for debugging
local joystickPlayer = { x = 0, y = 0, radius = 0, knobRadius = 0, knobX = 0, knobY = 0, active = false }
local joystickCursor = { x = 0, y = 0, radius = 0, knobRadius = 0, knobX = 0, knobY = 0, active = false }
local buttons = {}

local miniInventorySlots = 9 -- Number of slots in the mini inventory
local isFullInventoryOpen = false -- Whether the full inventory is open

local passthruBlocks = {"log"} -- Blocks that can be passed through

local isPaused = false -- Flag to track if the game is paused
local pauseMenuOptions = {"Resume", "Save and Quit", "Settings"}
local selectedPauseOption = 1 -- Index of the currently selected pause menu option

local playerImage -- Store the loaded player image
local bgMusic -- Background music source
local breakSound -- Block break sound
local placeSound -- Block place sound

-- Daylight cycle variables
local timeOfDay = 0.25      -- 0.25 = sunrise, so day by default
local DAY_LENGTH = 600      -- Seconds for a full day-night cycle (e.g., 600 = 10 minutes)
local DAY_COLOR = {0, 0.78, 1}
local NIGHT_COLOR = {0.05, 0.05, 0.15}
local SUNSET_COLOR = {0.9, 0.5, 0.2}
local SUNRISE_COLOR = {0.8, 0.7, 0.4}

-- Utility: Clamp function
local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function updateMobileControlPositions()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Update joystick positions and sizes
    joystickPlayer.x = screenWidth * 0.15
    joystickPlayer.y = screenHeight * 0.75
    joystickPlayer.radius = screenWidth * 0.1
    joystickPlayer.knobRadius = joystickPlayer.radius * 0.4
    joystickPlayer.knobX = joystickPlayer.x
    joystickPlayer.knobY = joystickPlayer.y

    joystickCursor.x = screenWidth * 0.85
    joystickCursor.y = screenHeight * 0.75
    joystickCursor.radius = screenWidth * 0.1
    joystickCursor.knobRadius = joystickCursor.radius * 0.4
    joystickCursor.knobX = joystickCursor.x
    joystickCursor.knobY = joystickCursor.y

    -- Update button positions and sizes
    buttons = {
        jump = {
            x = screenWidth * 0.7,
            y = screenHeight * 0.6,
            width = screenWidth * 0.1,
            height = screenHeight * 0.1,
            label = "Jump"
        },
        place = {
            x = screenWidth * 0.8,
            y = screenHeight * 0.6,
            width = screenWidth * 0.1,
            height = screenHeight * 0.1,
            label = "Place"
        },
        breakBlock = {
            x = screenWidth * 0.9,
            y = screenHeight * 0.6,
            width = screenWidth * 0.1,
            height = screenHeight * 0.1,
            label = "Break"
        }
    }
end

function game.preload()
    print("Game module preloaded. General assets can be loaded here.")
    -- Load player sprite
    local ok, img = pcall(love.graphics.newImage, "assets/images/player.png")
    if ok and img then
        playerImage = img
    else
        print("Warning: Could not load player image.")
        playerImage = nil
    end
    -- Load sounds
    local ok1, music = pcall(love.audio.newSource, "assets/sounds/bg-music.mp3", "stream")
    if ok1 and music then
        bgMusic = music
        bgMusic:setLooping(true)
        bgMusic:setVolume(musicVolume)
    else
        print("Warning: Could not load background music.")
        bgMusic = nil
    end
    local ok2, breakS = pcall(love.audio.newSource, "assets/sounds/break.mp3", "static")
    if ok2 and breakS then
        breakSound = breakS
        breakSound:setVolume(sfxVolume)
    else
        print("Warning: Could not load break sound.")
        breakSound = nil
    end
    local ok3, placeS = pcall(love.audio.newSource, "assets/sounds/place.mp3", "static")
    if ok3 and placeS then
        placeSound = placeS
        placeSound:setVolume(sfxVolume)
    else
        print("Warning: Could not load place sound.")
        placeSound = nil
    end
end

function game.setMusicVolume(vol)
    musicVolume = math.max(0, math.min(1, vol))
    if bgMusic then bgMusic:setVolume(musicVolume) end
end

function game.setSfxVolume(vol)
    sfxVolume = math.max(0, math.min(1, vol))
    if breakSound then breakSound:setVolume(sfxVolume) end
    if placeSound then placeSound:setVolume(sfxVolume) end
end

function game.getMusicVolume()
    return musicVolume
end

function game.getSfxVolume()
    return sfxVolume
end

function game.enterState(loadedWorldDataFromMenu)
    print("Game module: enterState() called.")
    width = love.graphics.getWidth()
    height = love.graphics.getHeight()
    love.graphics.setBackgroundColor(0, 0.78, 1) -- Set background for the game screen

    -- Initialize core game objects to default states
    player = {
        x = width / 2, -- Default position
        y = height / 2,
        speed = 300,
        gravity = 0,
        onGround = false,
        fallDistance = 0, -- For fall damage
        jump = function()
            if player.onGround then
                player.gravity = -10
                player.onGround = false
            end
        end
    }
    cursor = { x = 0, y = 0 }
    blocks = {} -- Start with an empty block list; loadWorldData will populate it
    camera = { x = 0, y = 0 } -- Reset camera

    -- Now, apply the specific world data
    if loadedWorldDataFromMenu then
        game.loadWorldData(loadedWorldDataFromMenu) -- game.enterState calls game.loadWorldData
    else
        print("Game.enterState: No world data provided, generating default world.")
        currentWorldName = "DefaultNewWorld_" .. os.time()
        currentWorldType = "default"
        currentWorldSeed = tostring(os.time())
        currentWorldVersion = 1.0
        worldGen.generate(currentWorldSeed, currentWorldType, currentWorldVersion) -- This populates 'blocks'
        player.x = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
        player.y = height / 4
        player.onGround = false
        player.gravity = 0
        worldPixelWidth = WORLD_WIDTH_BLOCKS * BLOCK_SIZE
    end

    -- Setup player properties based on game mode
    if currentGameMode == "survival" then
        player.health = 10
        player.maxHealth = 10
        player.fallDistance = 0
    elseif currentGameMode == "creative" then
        player.health = math.huge -- Effectively infinite
        player.maxHealth = math.huge
        player.fallDistance = 0 -- Still track for consistency, though no damage
        print("Creative mode active: Infinite health.")
    end
    isSelectingFile = false -- Ensure file selector is not active for in-game loading

    -- Start background music if not already playing
    if bgMusic and not bgMusic:isPlaying() then
        bgMusic:play()
    end

    -- Update mobile control positions
    updateMobileControlPositions()
end

function game.loadWorldData(worldDataFromFile)
    if not worldDataFromFile then
        print("Error in game.loadWorldData: No world data provided!")
        currentWorldData = nil
        return
    end

    -- Ensure player is initialized before accessing it
    if not player then
        player = {
            x = 0,
            y = 0,
            speed = 300,
            gravity = 0,
            onGround = false,
            jump = function()
                if player.onGround then
                    player.gravity = -10
                    player.onGround = false
                end
            end
        }
    end

    print("Game module is loading world: " .. (worldDataFromFile.w_data and worldDataFromFile.w_data.world_name or "Unnamed World"))
    currentWorldData = worldDataFromFile

    -- Load blocks
    if worldDataFromFile.blocks and type(worldDataFromFile.blocks) == "table" then
        blocks = worldDataFromFile.blocks -- Directly assign the blocks table
    else
        blocks = {} -- Should have been initialized in enterState, but good to be safe
        print("Warning: No 'blocks' table in world data or invalid. World will be empty or use defaults.")
    end

    -- Load world metadata (w_data) and set currentWorldName
    if worldDataFromFile.w_data and type(worldDataFromFile.w_data) == "table" then
        currentGameMode = worldDataFromFile.w_data.mode or "creative" -- Load mode, default to creative
        currentWorldName = worldDataFromFile.w_data.world_name or "UnnamedLoadedWorld"
        currentWorldType = worldDataFromFile.w_data.world_type or "default"
        currentWorldSeed = tostring(worldDataFromFile.w_data.world_seed or os.time())
        currentWorldVersion = worldDataFromFile.w_data.world_version or 1.0
    else
        currentWorldName = "LoadedWorld_NoMeta"
        currentGameMode = "creative" -- Default if no w_data
        currentWorldType = "default"
        currentWorldSeed = tostring(os.time())
        currentWorldVersion = 1.0
    end

    -- Load player position from the world file, overriding defaults set in enterState
    if worldDataFromFile.player and type(worldDataFromFile.player) == "table" then
        player.x = worldDataFromFile.player.x or player.x
        player.y = worldDataFromFile.player.y or player.y
    end
    -- Reset player physics state for the new world
    player.onGround = false
    player.gravity = 0
    player.fallDistance = 0 -- Reset fall distance on world load

    worldPixelWidth = WORLD_WIDTH_BLOCKS * BLOCK_SIZE
end

function game.update(dt)
    -- Only run update logic if the player exists and the game is not paused or in a menu
    if not player or isPaused or isSelectingFile or commandMenuOpen or isFullInventoryOpen then
        return
    end

    -- Ensure width and height are initialized
    if not width or not height then
        width = love.graphics.getWidth()
        height = love.graphics.getHeight()
    end

    -- Ensure the player object is initialized
    if not player then
        player = {
            x = width / 2,
            y = height / 2,
            speed = 300,
            gravity = 0,
            onGround = false,
            fallDistance = 0,
            jump = function()
                if player.onGround then
                    player.gravity = -10
                    player.onGround = false
                end
            end
        }
    end

    -- Ensure the cursor object is initialized
    if not cursor then
        cursor = { x = 0, y = 0 }
    end

    -- Ensure worldPixelWidth is initialized
    if not worldPixelWidth then
        worldPixelWidth = WORLD_WIDTH_BLOCKS * BLOCK_SIZE
    end

    -- Ensure blocks is initialized
    if not blocks then
        blocks = {}
    end

    -- Allow PC users to enable mobile controls for debugging
    if debugMobileControls then
        isMobile = true
    end

    -- Ensure selectedBlockType is valid
    if not availableBlockTypes[currentBlockTypeIndex] then
        currentBlockTypeIndex = 1
        selectedBlockType = availableBlockTypes[currentBlockTypeIndex]
    end

    if love.keyboard.isDown("w") or love.keyboard.isDown("space") then
        player.jump()
    end
    if love.keyboard.isDown("a") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + player.speed * dt
    end

    -- Handle player joystick movement
    if isMobile and joystickPlayer.active then
        local dx = joystickPlayer.knobX - joystickPlayer.x
        local dy = joystickPlayer.knobY - joystickPlayer.y
        local distance = math.sqrt(dx^2 + dy^2)
        if distance > joystickPlayer.radius then
            dx = dx / distance * joystickPlayer.radius
            dy = dy / distance * joystickPlayer.radius
        end

        if math.abs(dx) > 10 then
            player.x = player.x + (dx / joystickPlayer.radius) * player.speed * dt
        end
        if dy < -10 then
            player.jump()
        end
    end

    -- Handle cursor joystick movement
    if isMobile and joystickCursor.active then
        local dx = joystickCursor.knobX - joystickCursor.x
        local dy = joystickCursor.knobY - joystickCursor.y
        local distance = math.sqrt(dx^2 + dy^2)
        if distance > joystickCursor.radius then
            dx = dx / distance * joystickCursor.radius
            dy = dy / distance * joystickCursor.radius
        end

        cursor.x = cursor.x + (dx / joystickCursor.radius) * BLOCK_SIZE * dt
        cursor.y = cursor.y + (dy / joystickCursor.radius) * BLOCK_SIZE * dt
    end

    -- Disable cursor snapping in mobile mode
    if not isMobile then
        local mx, my = love.mouse.getPosition()
        cursor.x = math.floor((mx + camera.x) / BLOCK_SIZE) * BLOCK_SIZE
        cursor.y = math.floor((my + camera.y) / BLOCK_SIZE) * BLOCK_SIZE
    end

    -- Keep the player within the world bounds
    player.x = clamp(player.x, 0, math.max(0, worldPixelWidth - BLOCK_SIZE))

    -- Apply gravity & track fall distance
    if not player.onGround then
        player.gravity = player.gravity + 0.5
        player.y = player.y + player.gravity
        if player.gravity > 0 then -- Only count falling downwards
            player.fallDistance = player.fallDistance + player.gravity -- Approximate fall distance by summing gravity effect
        end
    else
        player.fallDistance = 0 -- Reset when on ground
    end
    -- Temporary: If player falls too far, reset to a high position (simulating falling out of world)
    if player.y > height * 3 then -- Arbitrary large value
        player.y = 0
        player.gravity = 0
        player.x = worldPixelWidth / 2
    end

    -- Reset ground state at the beginning of each frame
    player.onGround = false
    
    -- Check for collision with the blocks
    for i, block in ipairs(blocks) do
        if passthruBlocks and type(passthruBlocks) == "table" then
            for _, passthruType in ipairs(passthruBlocks) do
                if block.type == passthruType then
                    goto continue
                end
            end
        end

        if player.x < block.x + block.width and
           player.x + BLOCK_SIZE > block.x and -- Use BLOCK_SIZE for player width
           player.y < block.y + block.height and  -- Player top is above block bottom
           player.y + BLOCK_SIZE >= block.y then  -- Player bottom is at or below block top (use BLOCK_SIZE for player height)
            -- Collision detected, calculate overlap on each axis
            local overlapLeft = (player.x + BLOCK_SIZE) - block.x
            local overlapRight = (block.x + block.width) - player.x
            local overlapTop = (player.y + BLOCK_SIZE) - block.y
            local overlapBottom = (block.y + block.height) - player.y
            
            -- Find the smallest overlap to determine which direction to push
            local minOverlap = math.min(overlapLeft, overlapRight, overlapTop, overlapBottom)
            
            -- Push the player in the direction of minimum overlap
            if minOverlap == overlapLeft then
                -- Push left
                player.x = block.x - BLOCK_SIZE
            elseif minOverlap == overlapRight then
                -- Push right
                player.x = block.x + block.width
            elseif minOverlap == overlapTop then
                -- Push up
                player.y = block.y - BLOCK_SIZE
                -- Reset gravity and set onGround only if landing (i.e., not moving upwards from a jump)
                if player.gravity >= 0 then
                    player.gravity = 0
                    player.onGround = true
                    if currentGameMode == "survival" and player.fallDistance > BLOCK_SIZE * 3.5 * 20 then -- Threshold for fall damage (approx 3.5 blocks, gravity units are different)
                        -- Fall distance is accumulated gravity, not block units directly.
                        -- Let's use a simpler block-based check after landing.
                        -- This fallDistance tracking is a bit rough. A better way is to store y before falling.
                        -- For now, let's apply damage based on a simplified impact.
                        local fallBlocks = math.floor(player.fallDistance / (BLOCK_SIZE * 15)) -- Very rough estimate
                        if fallBlocks > 3 then
                            local damage = fallBlocks - 3
                            game.takeDamage(damage)
                        end
                    end
                end
            elseif minOverlap == overlapBottom then
                -- Push down
                player.y = block.y + block.height
                -- Reverse gravity slightly when hitting a block from below
                if player.gravity < 0 then
                    player.gravity = 2
                end
            end
        end

        ::continue::
    end

    if player.onGround then
        player.gravity = 0
    end

    -- Update camera to follow player
    camera.x = player.x - width / 2 + BLOCK_SIZE / 2
    camera.y = player.y - height / 2 + BLOCK_SIZE / 2

    -- Clamp camera to world boundaries
    camera.x = math.max(0, math.min(camera.x, worldPixelWidth - width))
    camera.y = math.max(0, camera.y) -- No upper clamp for Y yet, can be added if world has defined top

    -- Update daylight cycle
    timeOfDay = (timeOfDay + dt / DAY_LENGTH) % 1
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

function lerpColor(c1, c2, t)
    return lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t)
end

local function getSkyColor()
    -- Minecraft-like: smooth transition between day, sunset, night, sunrise
    -- 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset, 1.0 = midnight
    if timeOfDay < 0.23 then
        -- Night to sunrise
        local t = timeOfDay / 0.23
        return lerpColor(NIGHT_COLOR, SUNRISE_COLOR, t)
    elseif timeOfDay < 0.27 then
        -- Sunrise to day
        local t = (timeOfDay - 0.23) / 0.04
        return lerpColor(SUNRISE_COLOR, DAY_COLOR, t)
    elseif timeOfDay < 0.73 then
        -- Day
        return DAY_COLOR[1], DAY_COLOR[2], DAY_COLOR[3]
    elseif timeOfDay < 0.77 then
        -- Day to sunset
        local t = (timeOfDay - 0.73) / 0.04
        return lerpColor(DAY_COLOR, SUNSET_COLOR, t)
    elseif timeOfDay < 0.9 then
        -- Sunset to night
        local t = (timeOfDay - 0.77) / 0.13
        return lerpColor(SUNSET_COLOR, NIGHT_COLOR, t)
    else
        -- Night
        return NIGHT_COLOR[1], NIGHT_COLOR[2], NIGHT_COLOR[3]
    end
end

function game.draw()
    -- Set sky color for daylight cycle (if implemented)
    if getSkyColor then
        local r, g, b = getSkyColor()
        love.graphics.clear(r, g, b)
    else
        love.graphics.clear()
    end

    local playerSize = BLOCK_SIZE -- Assuming player is same size as blocks

    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))

    -- Draw the blocks
    game.drawBlocks()

    -- Draw the player as an image if loaded, else fallback to rectangle
    if playerImage then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(playerImage, math.floor(player.x), math.floor(player.y), 0, playerSize / playerImage:getWidth(), playerSize / playerImage:getHeight())
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", math.floor(player.x), math.floor(player.y), playerSize, playerSize)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", math.floor(player.x), math.floor(player.y), playerSize, playerSize)
    end

    -- Draw placement preview / snapped cursor (relative to world)
    game.drawCursorPreview()

    love.graphics.pop()

    -- Draw UI elements (fixed on screen)
    if isSelectingFile then
        game.drawFileSelector()
    else
        game.drawUI()
    end

    -- Draw the command menu if it's open
    if commandMenuOpen then
        game.drawCommandMenu()
    end

    -- Draw the mini inventory
    game.drawMiniInventory()

    -- Draw the full inventory if open
    if isFullInventoryOpen then
        game.drawFullInventory()
    end

    -- Draw the pause menu if the game is paused
    if isPaused then
        game.drawPauseMenu()
    end

    -- Draw mobile controls last to ensure they are on top
    if isMobile then
        -- Draw player joystick
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.circle("fill", joystickPlayer.x, joystickPlayer.y, joystickPlayer.radius)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.circle("fill", joystickPlayer.knobX, joystickPlayer.knobY, joystickPlayer.knobRadius)

        -- Draw cursor joystick
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.circle("fill", joystickCursor.x, joystickCursor.y, joystickCursor.radius)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.circle("fill", joystickCursor.knobX, joystickCursor.knobY, joystickCursor.knobRadius)

        -- Draw buttons
        for _, button in pairs(buttons) do
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(button.label, button.x, button.y + button.height / 2 - 10, button.width, "center")
        end
    end

    if debugMode then
        -- Draw time of day (for polish/debug)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.format("Time: %.2f", timeOfDay), 10, height - 30)
    end
end

function game.takeDamage(amount)
    if currentGameMode ~= "survival" or not player or player.health == math.huge then
        return
    end

    player.health = player.health - amount
    print("Player took " .. amount .. " damage. Health: " .. player.health)
    if player.health <= 0 then
        print("Player has died!")
        -- Handle player death (e.g., respawn, game over screen)
        -- For now, just reset position and health
        player.health = player.maxHealth
        player.x = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
        player.y = height / 4
        player.gravity = 0
        player.fallDistance = 0
    end
end

function game.drawPauseMenu()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local menuWidth, menuHeight = screenWidth * 0.4, screenHeight * 0.3
    local menuX, menuY = (screenWidth - menuWidth) / 2, (screenHeight - menuHeight) / 2

    -- Draw the menu background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)

    -- Draw the menu options
    local optionHeight = menuHeight / #pauseMenuOptions
    for i, option in ipairs(pauseMenuOptions) do
        local optionY = menuY + (i - 1) * optionHeight
        if i == selectedPauseOption then
            love.graphics.setColor(1, 1, 0) -- Highlight the selected option
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, menuX, optionY + optionHeight / 4, menuWidth, "center")
    end

    -- Only draw settings UI if settings is "opened" (see below)
    if isPaused and game._pauseSettingsOpen and _G.mainMenu and _G.mainMenu.drawSettings then
        _G.mainMenu:drawSettings()
    end
end

function game.drawMiniInventory()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local slotSize = 50 -- Size of each inventory slot
    local inventoryWidth = miniInventorySlots * slotSize
    local inventoryX = (screenWidth - inventoryWidth) / 2
    local inventoryY = screenHeight - slotSize - 10 -- 10px margin from the bottom

    for i = 1, miniInventorySlots do
        local slotX = inventoryX + (i - 1) * slotSize
        local slotY = inventoryY

        -- Draw the slot background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        -- Draw the block visual in the slot
        local blockType = availableBlockTypes[i]
        if blockType then
            local r, g, b = game.getBlockColor(blockType)
            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", slotX + 5, slotY + 5, slotSize - 10, slotSize - 10)
        end

        -- Highlight the selected slot
        if i == currentBlockTypeIndex then
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("line", slotX - 2, slotY - 2, slotSize + 4, slotSize + 4)
        end
    end
end

function game.drawFullInventory()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local inventoryWidth = screenWidth * 0.8
    local inventoryHeight = screenHeight * 0.6
    local inventoryX = (screenWidth - inventoryWidth) / 2
    local inventoryY = (screenHeight - inventoryHeight) / 2

    -- Draw the inventory background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", inventoryX, inventoryY, inventoryWidth, inventoryHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", inventoryX, inventoryY, inventoryWidth, inventoryHeight)

    -- Draw the block types in the inventory
    local slotSize = 50
    local cols = math.floor(inventoryWidth / slotSize)
    local rows = math.ceil(#availableBlockTypes / cols)

    for i, blockType in ipairs(availableBlockTypes) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local slotX = inventoryX + col * slotSize
        local slotY = inventoryY + row * slotSize

        -- Draw the slot background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        -- Draw the block visual
        local r, g, b = game.getBlockColor(blockType)
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", slotX + 5, slotY + 5, slotSize - 10, slotSize - 10)

        -- Highlight the selected block type
        if blockType == selectedBlockType then
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("line", slotX - 2, slotY - 2, slotSize + 4, slotSize + 4)
        end
    end
end

function game.getBlockColor(blockType)
    -- Use blockColor.lua for all block color lookups
    return blockColor.getBlockColor(blockType)
end

function game.drawCursorPreview()
    local r, g, b = 0.5, 0.5, 1 -- Default preview color (light blue)
    if selectedBlockType == "dirt" then r, g, b = 0.6, 0.4, 0.2
    elseif selectedBlockType == "stone" then r, g, b = 0.5, 0.5, 0.5
    elseif selectedBlockType == "wood" then r, g, b = 0.4, 0.3, 0.1
    elseif selectedBlockType == "grass" then r, g, b = 0.2, 0.8, 0.2
    elseif selectedBlockType == "log" then r, g, b = 0.35, 0.2, 0.05
    elseif selectedBlockType == "leaves" then r, g, b = 0.1, 0.6, 0.1
    elseif selectedBlockType == "coal_ore" then r, g, b = 0.2, 0.2, 0.2
    elseif selectedBlockType == "iron_ore" then r, g, b = 0.7, 0.4, 0.2
    end
    -- Draw the cursor preview relative to the camera, so it needs to be inside the push/pop
    -- However, the cursor coordinates are already world coordinates.
    love.graphics.setColor(r, g, b, 0.5) -- Semi-transparent color of selected block
    love.graphics.rectangle("fill", math.floor(cursor.x), math.floor(cursor.y), BLOCK_SIZE, BLOCK_SIZE)
    love.graphics.setColor(1, 1, 1, 0.8) -- White outline for visibility
    love.graphics.rectangle("line", math.floor(cursor.x), math.floor(cursor.y), BLOCK_SIZE, BLOCK_SIZE)
end

function game.drawUI()
    -- draws the selected block type in the bottom center of the screen
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(selectedBlockType, width / 2, height - 85)

    if debugMode then
        love.graphics.setColor(1, 1, 1) -- Default white color
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        love.graphics.print("Player X: " .. math.floor(player.x) .. " Y: " .. math.floor(player.y), 10, 30)
        love.graphics.print("Camera X: " .. math.floor(camera.x) .. " Y: " .. math.floor(camera.y), 10, 50)
        love.graphics.print("On Ground: " .. tostring(player.onGround), 10, 70)
        local blockTypeText = selectedBlockType or "None"
        love.graphics.print("Selected Block: " .. blockTypeText .. " (Q/E to cycle)", 10, 90)
        love.graphics.print("World: " .. currentWorldName .. " (F5 Save, F6 New, F7 Load)", 10, 110)
        love.graphics.print("Mode: " .. currentGameMode, 10, 130)
    end

    if currentGameMode == "survival" and player and player.maxHealth ~= math.huge then
        local heartSize = 20
        local heartsX = width - (player.maxHealth * (heartSize + 5)) - 10
        local heartsY = 10
        for i = 1, player.maxHealth do
            if i <= player.health then
                love.graphics.setColor(1,0,0) -- Full heart
            else
                love.graphics.setColor(0.3,0.3,0.3) -- Empty heart
            end
            love.graphics.rectangle("fill", heartsX + (i-1) * (heartSize + 5), heartsY, heartSize, heartSize) -- Simple square hearts
        end
    end
end

function game.drawFileSelector()
    -- Draw a semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Select World to Load (F7)", 0, 50, width, "center")
    love.graphics.printf("Up/Down Arrows to Navigate, Enter to Load, Escape to Cancel", 0, 80, width, "center")

    if #availableWorldFiles == 0 then
        love.graphics.printf("No .lua files found in 'worlds' directory.", 0, height / 2, width, "center")
        return
    end

    local startY = 120
    local lineHeight = 20
    for i, fileName in ipairs(availableWorldFiles) do
        if i == selectedFileIndex then
            love.graphics.setColor(1, 1, 0) -- Highlight selected
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(fileName, 0, startY + (i - 1) * lineHeight, width, "center")
    end
end

function game.drawCommandMenu()
    -- Draw a semi-transparent background for the command input area
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", 0, height - 40, width, 40) -- At the bottom of the screen

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16)) -- Use a suitable font
    love.graphics.print(commandInput .. (math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""), 10, height - 30)
end

function game.keypressed(key)
    if isPaused then
        -- Handle pause menu navigation
        if key == "up" or key == "w" then
            selectedPauseOption = selectedPauseOption - 1
            if selectedPauseOption < 1 then
                selectedPauseOption = #pauseMenuOptions
            end
        elseif key == "down" or key == "s" then
            selectedPauseOption = selectedPauseOption + 1
            if selectedPauseOption > #pauseMenuOptions then
                selectedPauseOption = 1
            end
        elseif key == "return" or key == "kpenter" then
            if pauseMenuOptions[selectedPauseOption] == "Resume" then
                isPaused = false -- Resume the game
                game._pauseSettingsOpen = false
            elseif pauseMenuOptions[selectedPauseOption] == "Save and Quit" then
                game.saveWorld(currentWorldName) -- Save the game
                love.event.quit() -- Quit the game
            elseif pauseMenuOptions[selectedPauseOption] == "Settings" then
                game._pauseSettingsOpen = not game._pauseSettingsOpen -- Toggle settings open/close
            end
        elseif key == "escape" or key == "`" then
            isPaused = false -- Resume the game if Esc or ` is pressed again
            game._pauseSettingsOpen = false
        else
            -- Forward key events to settings menu only if settings is open
            if game._pauseSettingsOpen and _G.mainMenu and _G.mainMenu.keypressed then
                _G.mainMenu:keypressed(key)
            end
        end
        -- Forward key events to settings menu only if settings is open
        if game._pauseSettingsOpen and _G.mainMenu and _G.mainMenu.keypressed then
            _G.mainMenu:keypressed(key)
        end
        return -- Prevent further processing when the pause menu is active
    end

    -- Toggle pause menu
    if key == "escape" or key == "`" then
        isPaused = not isPaused
        selectedPauseOption = 1 -- Reset to the first option when opening the menu
        return -- Prevent further processing
    end

    if isSelectingFile then
        if key == "escape" then
            isSelectingFile = false
        elseif key == "up" then
            selectedFileIndex = math.max(1, selectedFileIndex - 1)
        elseif key == "down" then
            selectedFileIndex = math.min(#availableWorldFiles, selectedFileIndex + 1)
        elseif key == "return" or key == "kpenter" then
            if #availableWorldFiles > 0 and availableWorldFiles[selectedFileIndex] then
                local worldToLoad = availableWorldFiles[selectedFileIndex]:gsub("%.lua$", "") -- Remove .lua extension
                game.loadWorld(worldToLoad)
                -- currentWorldName is updated inside game.loadWorld on successful load
            end
            isSelectingFile = false
        end
        return -- Prevent other key presses while selecting file
    end

    -- Handle command menu toggle and input
    if key == "/" then
        commandMenuOpen = not commandMenuOpen
        if commandMenuOpen then
            love.keyboard.setTextInput(true) -- Enable text input when menu opens
            commandInput = "/" -- Start with a slash
        else
            love.keyboard.setTextInput(false) -- Disable text input when menu closes
        end
        return -- Consume the "/" key press
    elseif commandMenuOpen then
        game.handleCommandMenuInput(key)
        return -- Consume key presses when the menu is open
    end
    if key == "escape" then
        love.event.quit()
        game.saveWorld(currentWorldName) -- Save on quit
    end
    if key == "q" then -- Cycle previous block type
        currentBlockTypeIndex = currentBlockTypeIndex - 1
        if currentBlockTypeIndex < 1 then
            currentBlockTypeIndex = #availableBlockTypes
        end
        selectedBlockType = availableBlockTypes[currentBlockTypeIndex]
    elseif key == "e" then -- Toggle full inventory
        isFullInventoryOpen = not isFullInventoryOpen
    end
    if tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= miniInventorySlots then
        currentBlockTypeIndex = tonumber(key)
        selectedBlockType = availableBlockTypes[currentBlockTypeIndex] or availableBlockTypes[1]
    end
    if key == "f5" then
        game.saveWorld(currentWorldName)
        print("World '" .. currentWorldName .. "' saved.")
    end
    if key == "f11" then
        local currentFullscreen, currentFullscreenType = love.window.getFullscreen()
        love.window.setFullscreen(not currentFullscreen, currentFullscreenType)
    end
    if key == "f6" then
        -- For simplicity, new world just regenerates with default name for now
        -- A more robust system would ask for a name.
        local newWorldName = "World_" .. os.time() -- Make it unique to avoid overwriting
        local modeForNewWorld = currentGameMode or "creative" -- Use current mode or default to creative
        currentWorldName = newWorldName -- Update current world name
        currentGameMode = modeForNewWorld -- Set the mode for this new world
        currentWorldType = "default"
        currentWorldSeed = tostring(os.time())
        currentWorldVersion = 1.0
        worldGen.generate(currentWorldSeed, currentWorldType, currentWorldVersion) -- Generate a fresh set of blocks
        -- Reset player position for the new world
        player.x = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
        player.y = height / 4 -- Start high up in the air in the middle
        player.onGround = false
        game.enterState(nil) -- Re-call enterState to properly set up player for the mode
        print("Generated new world '"..currentWorldName.."'. Save with F5 if desired.")
    end
    if key == "f7" then
        isSelectingFile = true
        game.populateWorldList()
    end

    -- Toggle debug mode for mobile controls
    if key == "m" then
        debugMobileControls = not debugMobileControls
        print("Debug Mobile Controls: " .. tostring(debugMobileControls))
    end

    if key == "f3" then
        debugMode = not debugMode
        print("Debug Mode: " .. tostring(debugMode))
    end
end

function game.handleCommandMenuInput(key)
    if key == "backspace" then
        if #commandInput > 1 --[[ Keep the initial "/" ]] then
            commandInput = commandInput:sub(1, -2)
        elseif #commandInput == 1 and commandInput == "/" then
             -- Optional: close menu if backspace is pressed on just "/"
             -- commandMenuOpen = false
             -- love.keyboard.setTextInput(false)
        end
    elseif key == "return" or key == "kpenter" then
        game.executeCommand(commandInput)
        commandMenuOpen = false -- Close menu after executing
        love.keyboard.setTextInput(false)
        commandInput = "" -- Clear input for next time
    elseif key == "escape" then
        commandMenuOpen = false -- Allow escape to close
        love.keyboard.setTextInput(false)
        commandInput = "" -- Clear input
    end
    -- Other characters are handled by game.textinput
end

function game.executeCommand(fullCommandString)
    local commandName, arguments = fullCommandString:match("^/([%w_]+)%s*(.*)$")
    if commandName == "gamemode" then
        local newMode = arguments:match("^%s*(creative|survival)%s*$")
        if newMode then
            currentGameMode = newMode
            game.enterState(currentWorldData) -- Re-initialize player for the new mode
            print("Game mode changed to: " .. currentGameMode)
        else
            print("Invalid arguments for /gamemode. Use 'creative' or 'survival'.")
        end
    elseif commandName == "time" then
        local t = arguments:match("^%s*([%d%.]+)%s*$")
        t = tonumber(t)
        if t and t >= 0 and t <= 1 then
            timeOfDay = t % 1
            print("Time of day set to: " .. tostring(timeOfDay))
        else
            print("Usage: /time {value between 0 and 1}. Example: /time 0.5 (noon), /time 0.25 (sunrise)")
        end
    elseif commandName == "help" then
        print("Available commands:")
        print("/gamemode creative|survival - Change game mode")
        print("/time {0-1} - Set time of day (0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset)")
        print("/help - Show this help message")
    else
        print("Unknown command: " .. (commandName or fullCommandString))
    end
end

function game.populateWorldList()
    availableWorldFiles = {}
    selectedFileIndex = 1
    local items = love.filesystem.getDirectoryItems("worlds")
    for _, item in ipairs(items) do
        if item:match("%.lua$") then -- Check if it's a .lua file
            table.insert(availableWorldFiles, item)
        end
    end
end

function game.keyreleased(key)
end

function game.textinput(text)
    if commandMenuOpen then
        -- Prevent adding text if it makes the input too long or contains newlines
        if #commandInput < 100 and not text:match("[\n\r]") then
            commandInput = commandInput .. text
        end
    end
end

function game.mousepressed(x, y, button)
    if isFullInventoryOpen then
        local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
        local inventoryWidth = screenWidth * 0.8
        local inventoryHeight = screenHeight * 0.6
        local inventoryX = (screenWidth - inventoryWidth) / 2
        local inventoryY = (screenHeight - inventoryHeight) / 2
        local slotSize = 50
        local cols = math.floor(inventoryWidth / slotSize)

        -- Check if the click is inside the inventory
        if x >= inventoryX and x <= inventoryX + inventoryWidth and
           y >= inventoryY and y <= inventoryY + inventoryHeight then
            local col = math.floor((x - inventoryX) / slotSize)
            local row = math.floor((y - inventoryY) / slotSize)
            local index = row * cols + col + 1

            if availableBlockTypes[index] then
                selectedBlockType = availableBlockTypes[index]
                currentBlockTypeIndex = index
            end
        end

        return -- Prevent further processing if the full inventory is open
    end

    local worldX, worldY = x + camera.x, y + camera.y -- Convert screen to world coordinates
    if button == 1 then
        -- Check if the cursor is over a block
        for i, block in ipairs(blocks) do
            if worldX >= block.x and worldX < block.x + block.width and worldY >= block.y and worldY < block.y + block.height then
                -- Remove the block
                table.remove(blocks, i)
                if breakSound then breakSound:stop(); breakSound:play() end
                break
            end
        end
    end
    if button == 2 then
        -- Prevent placing a block if one already exists at that position
        local exists = false
        for _, block in ipairs(blocks) do
            if block.x == cursor.x and block.y == cursor.y then
                exists = true
                break
            end
        end
        if not exists then
            local block = {}
            block.x = cursor.x
            block.y = cursor.y
            block.width = BLOCK_SIZE
            block.height = BLOCK_SIZE
            block.type = selectedBlockType
            table.insert(blocks, block)
            if placeSound then placeSound:stop(); placeSound:play() end
        end
    end

    -- Only forward mouse events to settings menu if settings is open
    if isPaused and game._pauseSettingsOpen and _G.mainMenu and _G.mainMenu.mousepressed then
        if _G.mainMenu:mousepressed(x, y, button) then return end
    end
end

function game.mousereleased(x, y, button)
end

function game.mousemoved(x, y, dx, dy)
end

function game.touchpressed(id, x, y, dx, dy, pressure)
    if isMobile then
        -- Check if touch is on buttons
        for name, button in pairs(buttons) do
            if x >= button.x and x <= button.x + button.width and
               y >= button.y and y <= button.y + button.height then
                if name == "jump" then
                    player.jump()
                elseif name == "place" then
                    local block = {
                        x = math.floor(cursor.x / BLOCK_SIZE) * BLOCK_SIZE,
                        y = math.floor(cursor.y / BLOCK_SIZE) * BLOCK_SIZE,
                        width = BLOCK_SIZE,
                        height = BLOCK_SIZE,
                        type = selectedBlockType
                    }
                    table.insert(blocks, block)
                    if placeSound then placeSound:stop(); placeSound:play() end
                elseif name == "breakBlock" then
                    for i, block in ipairs(blocks) do
                        if cursor.x >= block.x and cursor.x < block.x + block.width and
                           cursor.y >= block.y and cursor.y < block.y + block.height then
                            table.remove(blocks, i)
                            if breakSound then breakSound:stop(); breakSound:play() end
                            break
                        end
                    end
                end
                return -- Stop further processing if a button was pressed
            end
        end

        -- Check if touch is on player joystick
        local distance = math.sqrt((x - joystickPlayer.x)^2 + (y - joystickPlayer.y)^2)
        if distance <= joystickPlayer.radius then
            joystickPlayer.active = true
            joystickPlayer.knobX = x
            joystickPlayer.knobY = y
            return -- Stop further processing if the player joystick was activated
        end

        -- Check if touch is on cursor joystick
        distance = math.sqrt((x - joystickCursor.x)^2 + (y - joystickCursor.y)^2)
        if distance <= joystickCursor.radius then
            joystickCursor.active = true
            joystickCursor.knobX = x
            joystickCursor.knobY = y
            return -- Stop further processing if the cursor joystick was activated
        end
    end

    -- If no UI element was interacted with, process the touch as a game world interaction
    local worldX, worldY = x + camera.x, y + camera.y -- Convert screen to world coordinates
    for i, block in ipairs(blocks) do
        if worldX >= block.x and worldX < block.x + block.width and
           worldY >= block.y and worldY < block.y + block.height then
            -- Remove the block
            table.remove(blocks, i)
            if breakSound then breakSound:stop(); breakSound:play() end
            return
        end
    end
    -- Place block if not already present (right-click equivalent)
    local exists = false
    for _, block in ipairs(blocks) do
        if math.floor(worldX / BLOCK_SIZE) * BLOCK_SIZE == block.x and math.floor(worldY / BLOCK_SIZE) * BLOCK_SIZE == block.y then
            exists = true
            break
        end
    end
    if not exists then
        local block = {
            x = math.floor(worldX / BLOCK_SIZE) * BLOCK_SIZE,
            y = math.floor(worldY / BLOCK_SIZE) * BLOCK_SIZE,
            width = BLOCK_SIZE,
            height = BLOCK_SIZE,
            type = selectedBlockType
        }
        table.insert(blocks, block)
        if placeSound then placeSound:stop(); placeSound:play() end
    end
end

function game.touchmoved(id, x, y, dx, dy, pressure)
    if isMobile then
        if joystickPlayer.active then
            joystickPlayer.knobX = x
            joystickPlayer.knobY = y
        end
        if joystickCursor.active then
            joystickCursor.knobX = x
            joystickCursor.knobY = y
        end
    end
end

function game.touchreleased(id, x, y, dx, dy, pressure)
    if isMobile then
        joystickPlayer.active = false
        joystickPlayer.knobX = joystickPlayer.x
        joystickPlayer.knobY = joystickPlayer.y

        joystickCursor.active = false
        joystickCursor.knobX = joystickCursor.x
        joystickCursor.knobY = joystickCursor.y
    end
end

function worldGen.generate(seed, world_type, world_version)
    -- Use provided seed or fallback to currentWorldSeed
    seed = seed or currentWorldSeed
    world_type = world_type or currentWorldType
    world_version = world_version or currentWorldVersion

    -- Set deterministic random seed
    math.randomseed(tonumber(seed))

    -- Generate the game world
    -- blocks table is now initialized in game.load() and cleared here if re-generating
    blocks = {} 
    
    -- Number of blocks horizontally
    local numBlocksX = WORLD_WIDTH_BLOCKS
    -- Base ground level (from bottom of screen) - adjust as needed
    local groundLevel = height - 200
    
    -- Generate terrain with height variation
    local terrainHeight = {}
    
    -- Initialize with base height
    for x = 0, numBlocksX do
        terrainHeight[x] = groundLevel
    end
    
    -- Apply simple noise to create hills
    local hillHeight = 3 -- Number of blocks high the hills can be
    for x = 0, numBlocksX do
        -- Add some random variation to height
        local variation = math.random(-hillHeight, hillHeight) * BLOCK_SIZE
        terrainHeight[x] = groundLevel + variation
    end
    
    -- Smooth the terrain
    for i = 1, 3 do -- Apply smoothing multiple times
        local newHeight = {}
        for x = 0, numBlocksX do
            local left = terrainHeight[math.max(0, x-1)] or terrainHeight[0]
            local right = terrainHeight[math.min(numBlocksX, x+1)] or terrainHeight[numBlocksX]
            newHeight[x] = (left + terrainHeight[x] + right) / 3
        end
        terrainHeight = newHeight
    end
    
    -- Create the blocks based on terrain height
    for x = 0, numBlocksX - 1 do
        local surfaceY = math.floor(terrainHeight[x] / BLOCK_SIZE) * BLOCK_SIZE
        
        -- Create a grass block for the surface
        local grassBlock = {
            x = x * BLOCK_SIZE,
            y = surfaceY,
            width = BLOCK_SIZE,
            height = BLOCK_SIZE,
            type = "grass"
        }
        table.insert(blocks, grassBlock)

        -- Create dirt blocks below grass (2 blocks deep)
        for y = 1, 2 do
            local block = {
                x = x * BLOCK_SIZE,
                y = surfaceY + (y * BLOCK_SIZE),
                width = BLOCK_SIZE,
                height = BLOCK_SIZE,
                type = "dirt"
            }
            table.insert(blocks, block)
        end

         -- Loop for the defined number of stone layers, adding ores
         for i = 0, NUM_STONE_LAYERS - 1 do
            local blockY = surfaceY + ((3 + i) * BLOCK_SIZE) -- Stone/ore starts 3 layers below surface (1 grass, 2 dirt)
            
            local blockType = "stone" -- Default to stone
            local r_val = math.random()

            -- Determine if this block should be an ore
            -- Check for rarer ores first
            if r_val < IRON_ORE_CHANCE then
                blockType = "iron_ore"
            elseif r_val < IRON_ORE_CHANCE + COAL_ORE_CHANCE then -- Check for coal after iron
                blockType = "coal_ore"
            end
            -- If neither ore condition is met, it remains "stone"

            local block = {
                x = x * BLOCK_SIZE,
                y = blockY,
                width = BLOCK_SIZE,
                height = BLOCK_SIZE,
                type = blockType
            }
            table.insert(blocks, block)
        end
    end

    -- Generate Trees
    local treeChance = 0.15 -- 15% chance to spawn a tree at a given spot
    for x = 2, numBlocksX - 3 do -- Iterate, leaving space at edges
        if math.random() < treeChance then
            local surfaceY = math.floor(terrainHeight[x] / BLOCK_SIZE) * BLOCK_SIZE
            local treeHeight = math.random(3, 5) -- Trunk height

            -- Place logs (trunk)
            for i = 1, treeHeight do
                local logBlock = {
                    x = x * BLOCK_SIZE,
                    y = surfaceY - (i * BLOCK_SIZE), -- Grow upwards from surface
                    width = BLOCK_SIZE,
                    height = BLOCK_SIZE,
                    type = "log"
                }
                table.insert(blocks, logBlock)
            end

            -- Place leaves (canopy) - simple 3x3 or 5x2 on top
            local canopyTopY = surfaceY - (treeHeight * BLOCK_SIZE) - BLOCK_SIZE
            for lx = -1, 1 do -- 3 blocks wide
                for ly = -1, 0 do -- 2 blocks tall, starting above the trunk
                    local leafBlock = {
                        x = (x + lx) * BLOCK_SIZE,
                        y = canopyTopY + (ly * BLOCK_SIZE),
                        width = BLOCK_SIZE,
                        height = BLOCK_SIZE,
                        type = "leaves"
                    }
                    table.insert(blocks, leafBlock)
                end
            end
        end
    end
    print("World generated with " .. #blocks .. " blocks.")
end

function game.drawBlocks()
    -- Draw the blocks
    for i, block in ipairs(blocks) do
        if block.type == "dirt" then
            -- Brown for dirt
            love.graphics.setColor(0.6, 0.4, 0.2)
        elseif block.type == "stone" then
            -- Gray for stone
            love.graphics.setColor(0.5, 0.5, 0.5)
        elseif block.type == "wood" then
            -- Brown for wood (example color)
            love.graphics.setColor(0.4, 0.25, 0.1)
        elseif block.type == "grass" then
            -- Green for grass
            love.graphics.setColor(0.2, 0.8, 0.2)
        elseif block.type == "log" then
            -- Darker brown for log
            love.graphics.setColor(0.35, 0.2, 0.05)
        elseif block.type == "leaves" then
            -- Dark green for leaves
            love.graphics.setColor(0.1, 0.6, 0.1)
        elseif block.type == "coal_ore" then
            -- Dark gray for coal ore (slightly different from stone)
            love.graphics.setColor(0.3, 0.3, 0.3)
        elseif block.type == "iron_ore" then
            -- Reddish-brown for iron ore
            love.graphics.setColor(0.7, 0.4, 0.2)
        else
            -- Green for any other blocks
            love.graphics.setColor(0, 1, 0)
        end

        -- View Culling: Only draw blocks visible in camera
        if block.x + block.width > camera.x and 
           block.x < camera.x + width and
           block.y + block.height > camera.y and
           block.y < camera.y + height then
            love.graphics.rectangle("fill", math.floor(block.x), math.floor(block.y), block.width, block.height)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", math.floor(block.x), math.floor(block.y), block.width, block.height)
        end
    end
end

-- World Save/Load Functions
function game.saveWorld(worldName)
    -- Ensure the "worlds" directory exists
    local worldDir = "/home/sheldi/Documents/lua/love2d/MiniCraft/worlds"
    local worldDirInfo = love.filesystem.getInfo(worldDir)
    if not worldDirInfo or worldDirInfo.type ~= "directory" then
        local success, msg = love.filesystem.createDirectory(worldDir)
        if not success then
            print("Error creating 'worlds' directory: " .. tostring(msg))
            return
        end
    end

    -- Construct the absolute file path
    local filePath = worldDir .. "/" .. worldName .. ".lua"

    -- Prepare content
    local content = "return {\n"
    content = content .. "    blocks = {\n"
    for _, block in ipairs(blocks) do
        content = content .. string.format(
            "        { x = %d, y = %d, width = %d, height = %d, type = \"%s\" },\n",
            block.x, block.y, block.width, block.height, block.type
        )
    end
    content = content .. "    },\n"

    -- Add player data
    content = content .. string.format(
        "    player = { x = %d, y = %d },\n",
        math.floor(player.x), math.floor(player.y)
    )

    -- Add world metadata
    content = content .. string.format(
        "    w_data = { mode = \"%s\", world_name = \"%s\", world_type = \"%s\", world_seed = \"%s\", world_version = %s }\n",
        currentGameMode, worldName, currentWorldType, tostring(currentWorldSeed), tostring(currentWorldVersion)
    )
    content = content .. "}\n"

    -- Write the file (overwrites if it already exists)
    local file = io.open(filePath, "w")
    if file then
        file:write(content)
        file:close()
        print("World '" .. worldName .. "' saved successfully to: " .. filePath)
    else
        print("Error saving world '" .. worldName .. "': Could not open file for writing.")
    end
end

function game.loadWorld(worldName)
    local worldPath = "worlds/" .. worldName .. ".lua"
    local dataLoadedSuccessfully = false
    local loadedWorldData

    -- Step 1: Try to load the file. love.filesystem.load returns a function (chunk) on success.
    local chunk, loadErrorMessage = love.filesystem.load(worldPath)

    if not chunk then -- This means love.filesystem.getInfo(worldPath) would also be false or error.
        -- This case is hit if the file literally doesn't exist or is unreadable by LÖVE.
        -- The `world_select.lua` should ideally only list existing, readable .lua files.
        -- If we reach here via F7 load for a non-existent file, generation is a valid fallback.
        print("Could not load world file '" .. worldPath .. "' (love.filesystem.load failed). Error: " .. tostring(loadErrorMessage))
        -- dataLoadedSuccessfully remains false, will proceed to generate new world
    else
        -- Step 2: Try to execute the loaded chunk. This will run the code in the world file.
        local executeSuccess, resultFromChunk = pcall(chunk)

        if not executeSuccess then
            print("Error executing world file '" .. worldPath .. "'. Error: " .. tostring(resultFromChunk))
            -- dataLoadedSuccessfully remains false
        elseif type(resultFromChunk) ~= "table" then
            print("World file '" .. worldPath .. "' did not return a valid data table. Expected table, got " .. type(resultFromChunk) .. ". Content: " .. tostring(resultFromChunk))
            -- dataLoadedSuccessfully remains false
        else
            -- Successfully loaded and executed, and it returned a table.
            -- This is the "happy path" for loading an existing, valid world file.
            loadedWorldData = resultFromChunk
            dataLoadedSuccessfully = true
        end
    end

    -- This part is now largely duplicated by game.enterState and game.loadWorldData.
    if dataLoadedSuccessfully then
        -- Load blocks
        if loadedWorldData.blocks and type(loadedWorldData.blocks) == "table" then
            blocks = loadedWorldData.blocks
        else
            blocks = {} -- Initialize to empty if blocks field is missing or not a table
            print("No 'blocks' table found in world data or it was invalid. Starting with an empty block set.")
        end

        -- Load world metadata (w_data) and set currentWorldName
        if loadedWorldData.w_data and type(loadedWorldData.w_data) == "table" then
            if loadedWorldData.w_data.world_name then
                currentWorldName = loadedWorldData.w_data.world_name
                currentGameMode = loadedWorldData.w_data.mode or "creative"
                currentWorldType = loadedWorldData.w_data.world_type or "default"
                currentWorldSeed = tostring(loadedWorldData.w_data.world_seed or os.time())
                currentWorldVersion = loadedWorldData.w_data.world_version or 1.0
            else
                currentWorldName = worldName
                currentGameMode = "creative"
                currentWorldType = "default"
                currentWorldSeed = tostring(os.time())
                currentWorldVersion = 1.0
            end
            print("Loaded w_data: mode=" .. tostring(loadedWorldData.w_data.mode) ..
                ", type=" .. tostring(currentWorldType) ..
                ", seed=" .. tostring(currentWorldSeed) ..
                ", version=" .. tostring(currentWorldVersion) ..
                ", name=" .. currentWorldName)
        else
            currentWorldName = worldName
            currentGameMode = "creative"
            currentWorldType = "default"
            currentWorldSeed = tostring(os.time())
            currentWorldVersion = 1.0
            print("No 'w_data' table found in world data. Using filename as world name.")
        end

        print("World '" .. currentWorldName .. "' loaded with " .. #blocks .. " blocks.")

        -- Load player position, with fallback
        local playerPositionLoadedFromFile = false
        if loadedWorldData.player and type(loadedWorldData.player) == "table" then
            player.x = loadedWorldData.player.x or (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
            player.y = loadedWorldData.player.y or (height / 2)
            playerPositionLoadedFromFile = true
            print("Player position loaded from file: X=" .. player.x .. ", Y=" .. player.y)
        end

        if not playerPositionLoadedFromFile then
            print("Player position not in world file or invalid. Using fallback placement.")
            if #blocks > 0 then
                local midWorldX = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
                local topMostSurfaceY = math.huge -- Smallest Y value is highest on screen
                local surfaceBlockFoundInMiddle = false
                for _,b in ipairs(blocks) do
                    if b.x >= midWorldX - BLOCK_SIZE*10 and b.x <= midWorldX + BLOCK_SIZE*10 then
                        if b.y < topMostSurfaceY then topMostSurfaceY = b.y end
                        surfaceBlockFoundInMiddle = true
                    end
                end
                if surfaceBlockFoundInMiddle then
                     player.x = midWorldX
                     player.y = topMostSurfaceY - BLOCK_SIZE * 2 -- Place 2 blocks above the found surface
                else player.x = midWorldX; player.y = height / 2 end
            else player.x = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE; player.y = height / 2 end
            print("Fallback player position set: X=" .. player.x .. ", Y=" .. player.y)
        end
    else -- Load failed at some stage (file not found, execution error, or not a table)
        -- This path means the file might exist but is corrupt, or didn't exist and love.filesystem.load failed.
        print("Failed to load world '" .. worldName .. "'. Generating a new world with this name.")
        blocks = {} -- Ensure blocks is empty before generating
        currentGameMode = "creative" -- Default to creative for newly generated from F7 fail
        currentWorldType = "default"
        currentWorldSeed = tostring(os.time())
        currentWorldVersion = 1.0
        worldGen.generate(currentWorldSeed, currentWorldType, currentWorldVersion)
        -- Place player after new generation
        player.x = (WORLD_WIDTH_BLOCKS / 2) * BLOCK_SIZE
        player.y = height / 4 -- Start high up in the air
        currentWorldName = worldName -- Use the intended name for the new world.
    end
    -- After loading or generating, re-initialize player state based on the determined currentGameMode
    -- This is a bit redundant with enterState, but ensures F7 load also correctly sets up player for the mode.
    -- A cleaner way would be for game.loadWorld to return the loaded data, and then main logic calls enterState.
    -- For now, this explicit setup will work:
    game.enterState(loadedWorldData) -- Pass the loaded data (or nil if generation happened) to re-setup player
end

function game.getBlocks()
    return blocks
end
function game.getPlayer()
    return player
end
function game.getCursor()
    return cursor
end

function game.wheelmoved(x, y)
    -- Handle mouse wheel movement
    if y > 0 then
        -- Scroll up
        currentBlockTypeIndex = currentBlockTypeIndex + 1
        if currentBlockTypeIndex > #availableBlockTypes then
            currentBlockTypeIndex = 1
        end
        selectedBlockType = availableBlockTypes[currentBlockTypeIndex]
    elseif y < 0 then
        -- Scroll down
        currentBlockTypeIndex = currentBlockTypeIndex - 1
        if currentBlockTypeIndex < 1 then
            currentBlockTypeIndex = #availableBlockTypes
        end
        selectedBlockType = availableBlockTypes[currentBlockTypeIndex]
    end
end

function love.resize(w, h)
    width = w
    height = h
    updateMobileControlPositions() -- Update controls on screen resize
end

return game