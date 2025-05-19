-- /home/sheldi/Documents/lua/love2d/MiniCraft/world_select.lua
local WorldSelectMenu = {}

WorldSelectMenu.buttons = {}
WorldSelectMenu.worlds = {} -- { name = "WorldName", path = "worlds/WorldName.lua" }
WorldSelectMenu.scrollOffset = 0
WorldSelectMenu.itemHeight = 45
WorldSelectMenu.listVisibleItems = 0

local screenWidth = 0
local screenHeight = 0
local listX, listY, listWidth, listHeight = 0,0,0,0

-- For creating/renaming worlds
WorldSelectMenu.isNamingWorld = false
WorldSelectMenu.namingAction = nil -- "create" or "rename"
WorldSelectMenu.worldNameInput = ""
WorldSelectMenu.originalName = nil -- for renaming
WorldSelectMenu.popupRect = {}

function WorldSelectMenu:initFontsAndColors()
    self.titleFont = love.graphics.newFont(36)
    self.worldFont = love.graphics.newFont(20)
    self.buttonFont = love.graphics.newFont(18)
    self.inputFont = love.graphics.newFont(20)

    self.colors = {
        text = {0,0,0},
        button = {0.7, 0.7, 0.7},
        buttonHover = {0.85, 0.85, 0.85},
        worldItem = {0.9, 0.9, 0.9},
        worldItemHover = {1,1,1},
        popupBg = {0.2, 0.2, 0.2, 0.95},
        popupBorder = {0.5,0.5,0.5},
        inputBg = {1,1,1},
        inputText = {0,0,0}
    }
end

function WorldSelectMenu:calculateLayout()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    listX = 50
    listY = 100
    listWidth = screenWidth - 100
    listHeight = screenHeight - 230
    self.listVisibleItems = math.floor(listHeight / self.itemHeight)

    local bottomButtonY = screenHeight - 50 - self.itemHeight
    local bottomButtonWidth = 200

    self.buttons = {
        {
            id = "back", text = "Back to Menu",
            x = listX, y = bottomButtonY,
            width = bottomButtonWidth, height = self.itemHeight,
            action = function() switchGameState("menu") end
        },
        {
            id = "create", text = "Create New World",
            x = screenWidth - listX - bottomButtonWidth, y = bottomButtonY,
            width = bottomButtonWidth, height = self.itemHeight,
            action = function()
                self.isNamingWorld = true
                self.namingAction = "create"
                self.worldNameInput = "MyNewWorld"
                self.originalName = nil
                love.keyboard.setTextInput(true) -- Enable text input globally
            end
        }
    }

    local popupWidth = 400
    local popupHeight = 180
    self.popupRect = {
        x = screenWidth / 2 - popupWidth / 2,
        y = screenHeight / 2 - popupHeight / 2,
        width = popupWidth,
        height = popupHeight
    }
    self.popupRect.inputY = self.popupRect.y + 60
    self.popupRect.inputH = 40
    self.popupRect.okButton = {
        text = "OK",
        x = self.popupRect.x + popupWidth/2 - 110, y = self.popupRect.y + popupHeight - 55,
        width = 100, height = 40
    }
    self.popupRect.cancelButton = {
        text = "Cancel",
        x = self.popupRect.x + popupWidth/2 + 10, y = self.popupRect.y + popupHeight - 55,
        width = 100, height = 40
    }
end


function WorldSelectMenu:load()
    self:initFontsAndColors()
    self:calculateLayout()

    self.worlds = {}
    self.scrollOffset = 0
    self.isNamingWorld = false
    self.worldNameInput = ""

    if not love.filesystem.getInfo("worlds") then
        love.filesystem.createDirectory("worlds")
    end

    local items, err = love.filesystem.getDirectoryItems("worlds")
    if not items then
        print("Warning: Could not read 'worlds' directory: " .. (err or "Unknown error"))
        items = {}
    end

    for _, item in ipairs(items) do
        if item:match("%.lua$") then
            local worldName = item:gsub("%.lua$", "")
            table.insert(self.worlds, { name = worldName, path = "worlds/" .. item })
        end
    end
    table.sort(self.worlds, function(a,b) return a.name < b.name end)
end

function WorldSelectMenu:update(dt)
    -- Update logic for scroll, etc.
end

function WorldSelectMenu:drawButton(button, font)
    font = font or self.buttonFont
    local mx, my = love.mouse.getPosition()
    local isHovered = false
    if not self.isNamingWorld or (button.id == "popup_ok" or button.id == "popup_cancel") then -- Only allow popup buttons if popup is active
         isHovered = mx >= button.x and mx <= button.x + button.width and
                       my >= button.y and my <= button.y + button.height
    end

    if isHovered then
        love.graphics.setColor(self.colors.buttonHover)
    else
        love.graphics.setColor(self.colors.button)
    end
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
    love.graphics.setColor(self.colors.text)
    love.graphics.setFont(font)
    love.graphics.printf(button.text, button.x, button.y + button.height / 2 - font:getHeight() / 2, button.width, "center")
end

function WorldSelectMenu:drawWorldList()
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", listX, listY, listWidth, listHeight)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local mx, my = love.mouse.getPosition()

    for i = 1, #self.worlds do
        local idx = i + self.scrollOffset
        if idx > #self.worlds then break end
        if i > self.listVisibleItems + 1 then break end -- Draw one extra for smooth scroll appearance

        local world = self.worlds[idx]
        local yPos = listY + (i - 1) * self.itemHeight

        local itemRect = {x = listX + 5, y = yPos + 2, width = listWidth - 10, height = self.itemHeight - 4}
        local isHovered = mx >= itemRect.x and mx <= itemRect.x + itemRect.width and
                          my >= itemRect.y and my <= itemRect.y + itemRect.height and not self.isNamingWorld

        if isHovered then love.graphics.setColor(self.colors.worldItemHover)
        else love.graphics.setColor(self.colors.worldItem) end
        love.graphics.rectangle("fill", itemRect.x, itemRect.y, itemRect.width, itemRect.height, 3, 3)

        love.graphics.setColor(self.colors.text)
        love.graphics.setFont(self.worldFont)
        love.graphics.printf(world.name, itemRect.x + 15, itemRect.y + itemRect.height / 2 - self.worldFont:getHeight() / 2, itemRect.width - 340, "left")

        world.playButton = { id="play", text = "Play", x = itemRect.x + itemRect.width - 320, y = itemRect.y + 5, width = 100, height = self.itemHeight - 14 }
        self:drawButton(world.playButton)

        world.renameButton = { id="rename", text = "Rename", x = itemRect.x + itemRect.width - 210, y = itemRect.y + 5, width = 100, height = self.itemHeight - 14 }
        self:drawButton(world.renameButton)

        world.deleteButton = { id="delete", text = "Delete", x = itemRect.x + itemRect.width - 100, y = itemRect.y + 5, width = 100, height = self.itemHeight - 14 }
        self:drawButton(world.deleteButton)
    end
    love.graphics.setStencilTest()
    love.graphics.setColor(1,1,1)
end

function WorldSelectMenu:drawNamingPopup()
    if not self.isNamingWorld then return end
    local p = self.popupRect

    love.graphics.setColor(self.colors.popupBg)
    love.graphics.rectangle("fill", p.x, p.y, p.width, p.height, 10, 10)
    love.graphics.setColor(self.colors.popupBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.width, p.height, 10, 10)
    love.graphics.setLineWidth(1)

    local title = ""
    if self.namingAction == "create" then
        title = "Enter New World Name:"
    elseif self.namingAction == "rename" then
        title = "Rename World:"
    elseif self.namingAction == "delete" then
        title = "Are you sure you want to delete this world?"
    end

    love.graphics.setFont(self.worldFont)
    love.graphics.setColor(1,1,1)
    love.graphics.printf(title, p.x + 10, p.y + 20, p.width - 20, "left")

    if self.namingAction == "delete" then
        love.graphics.setFont(self.inputFont)
        love.graphics.printf(self.worldNameInput, p.x + 20, p.inputY, p.width - 40, "center")
    else
        love.graphics.setColor(self.colors.inputBg)
        love.graphics.rectangle("fill", p.x + 20, p.inputY, p.width - 40, p.inputH)
        love.graphics.setColor(self.colors.inputText)
        love.graphics.setFont(self.inputFont)
        love.graphics.printf(self.worldNameInput .. (math.floor(love.timer.getTime()*2) % 2 == 0 and "_" or ""), p.x + 25, p.inputY + p.inputH/2 - self.inputFont:getHeight()/2, p.width - 50, "left")
    end

    p.okButton.id = "popup_ok"
    p.cancelButton.id = "popup_cancel"
    self:drawButton(p.okButton, self.worldFont)
    self:drawButton(p.cancelButton, self.worldFont)
    love.graphics.setColor(1,1,1)
end

function WorldSelectMenu:draw()
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Select or Create World", 0, 30, screenWidth, "center")

    self:drawWorldList()

    for _, button in ipairs(self.buttons) do
        self:drawButton(button)
    end
    love.graphics.setColor(1, 1, 1)

    self:drawNamingPopup()
end

function WorldSelectMenu:handlePopupClick(x, y)
    if not self.isNamingWorld then return false end
    local p = self.popupRect

    local function checkBtn(btn)
        return x >= btn.x and x <= btn.x + btn.width and y >= btn.y and y <= btn.y + btn.height
    end

    if checkBtn(p.okButton) then
        if self.namingAction == "delete" then
            self:deleteWorld(self.originalName)
        elseif self.worldNameInput and #self.worldNameInput > 0 then
            if self.namingAction == "create" then
                self:createNewWorld(self.worldNameInput)
            elseif self.namingAction == "rename" then
                self:renameWorld(self.originalName, self.worldNameInput)
            end
        end
        self.isNamingWorld = false
        love.keyboard.setTextInput(false)
        return true
    end

    if checkBtn(p.cancelButton) then
        self.isNamingWorld = false
        love.keyboard.setTextInput(false)
        return true
    end
    return false
end

function WorldSelectMenu:mousepressed(x, y, btn)
    if btn == 1 then
        if self.isNamingWorld then
            if self:handlePopupClick(x,y) then return true end
            local p = self.popupRect
            if not (x >= p.x and x <= p.x + p.width and y >= p.y and y <= p.y + p.height) then
                self.isNamingWorld = false; love.keyboard.setTextInput(false)
            else return true end -- Click was inside popup, handled or consumed
        end

        for _, button in ipairs(self.buttons) do
            if x >= button.x and x <= button.x + button.width and
               y >= button.y and y <= button.y + button.height then
                if button.action then button.action(); return true end
            end
        end

        -- Check world list buttons
        if x >= listX and x <= listX + listWidth and y >= listY and y <= listY + listHeight then
            for i = 1, self.listVisibleItems + 1 do
                 local idx = i + self.scrollOffset
                 if idx > #self.worlds then break end
                 local world = self.worlds[idx]
                 local yBase = listY + (i - 1) * self.itemHeight

                if world.playButton and x >= world.playButton.x and x <= world.playButton.x + world.playButton.width and
                   y >= world.playButton.y and y <= world.playButton.y + world.playButton.height then
                    print("Playing world: " .. world.path)
                    local success, worldModule = pcall(require, world.path:gsub("%.lua$", ""))
                    if success and worldModule then
                        if game and game.loadWorldData then
                            game.loadWorldData(worldModule)
                            switchGameState("game") 
                        else
                            print("Error: game module or game.loadWorldData not found.")
                        end
                    else
                        print("Error loading world file: " .. world.path .. " - " .. tostring(worldModule))
                    end
                    return true
                end

                if world.renameButton and x >= world.renameButton.x and x <= world.renameButton.x + world.renameButton.width and
                   y >= world.renameButton.y and y <= world.renameButton.y + world.renameButton.height then
                    self.isNamingWorld = true
                    self.namingAction = "rename"
                    self.worldNameInput = world.name
                    self.originalName = world.name
                    love.keyboard.setTextInput(true)
                    return true
                end

                if world.deleteButton and x >= world.deleteButton.x and x <= world.deleteButton.x + world.deleteButton.width and
                   y >= world.deleteButton.y and y <= world.deleteButton.y + world.deleteButton.height then
                    self:confirmDeleteWorld(world)
                    return true
                end
            end
        end
    end
    return false
end

function WorldSelectMenu:wheelmoved(dx, dy) -- LÖVE 11.0+ signature
    local scrollAmount = 0
    -- dy > 0 means scrolled "down" (mouse wheel away from user)
    -- dy < 0 means scrolled "up" (mouse wheel towards user)
    -- To scroll the list content down (see items further down), we increase offset.
    if dy > 0 then scrollAmount = 1      -- Scroll wheel down, view items below
    elseif dy < 0 then scrollAmount = -1 -- Scroll wheel up, view items above
    end
    if scrollAmount ~= 0 then
        self.scrollOffset = self.scrollOffset + scrollAmount
        self.scrollOffset = math.max(0, self.scrollOffset)
        self.scrollOffset = math.min(self.scrollOffset, math.max(0, #self.worlds - self.listVisibleItems))
    end
end


function WorldSelectMenu:textinput(text)
    if self.isNamingWorld then
        self.worldNameInput = self.worldNameInput .. text
    end
end

function WorldSelectMenu:keypressed(key)
    if self.isNamingWorld then
        if key == "backspace" then
            self.worldNameInput = self.worldNameInput:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            if self:handlePopupClick(self.popupRect.okButton.x + 1, self.popupRect.okButton.y + 1) then end -- Simulate OK
        elseif key == "escape" then
            if self:handlePopupClick(self.popupRect.cancelButton.x + 1, self.popupRect.cancelButton.y + 1) then end -- Simulate Cancel
        end
        return true
    end
    if key == "down" then
        self.scrollOffset = math.min(self.scrollOffset + 1, math.max(0, #self.worlds - self.listVisibleItems))
        return true
    elseif key == "up" then
        self.scrollOffset = math.max(0, self.scrollOffset - 1)
        return true
    end
    return false
end

function WorldSelectMenu:createNewWorld(name)
    local sanitizedName = name:gsub("[^%w_%.%-%s]", ""):gsub("^%s*(.-)%s*$", "%1") -- Allow alphanumeric, underscore, dot, hyphen, space. Trim.
    if #sanitizedName == 0 then print("Invalid world name."); return end

    local newWorldPath = "worlds/" .. sanitizedName .. ".lua"
    if love.filesystem.getInfo(newWorldPath) then
        print("World already exists: " .. newWorldPath); return
    end

    local templatePath = "worlds/NewWorld.lua" -- Assuming this is your template
    local templateContent
    if love.filesystem.getInfo(templatePath) then
        templateContent = love.filesystem.read(templatePath)
    end

    if not templateContent then
        print("Warning: Template 'worlds/NewWorld.lua' not found. Creating a minimal world file.")
        templateContent = string.format([[
local world_data = {
    blocks = {},
    player = { x = 400, y = 300 },
    w_data = {
        mode = "creative",
        seed = %d,
        world_name = "%s",
        mods = nil,
        world_type = "default"
    }
}
return world_data
        ]], math.floor(love.timer.getTime() * 1000 + math.random() * 1000), sanitizedName:gsub('"', '\"'))
    else
        templateContent = templateContent:gsub('world_name = "NewWorld"', 'world_name = "' .. sanitizedName:gsub('"', '\"') .. '"', 1)
        templateContent = templateContent:gsub('seed = 123456789', 'seed = ' .. tostring(math.floor(love.timer.getTime()*1000 + math.random() * 1000)), 1)
    end

    if love.filesystem.write(newWorldPath, templateContent) then
        print("Created new world: " .. newWorldPath)
        self:load() -- Reload list
    else
        print("Error creating world file: " .. newWorldPath)
    end
end

function WorldSelectMenu:renameWorld(oldName, newName)
    local sanitizedNewName = newName:gsub("[^%w_%.%-%s]", ""):gsub("^%s*(.-)%s*$", "%1")
    if #sanitizedNewName == 0 or not oldName then print("Invalid names for rename."); return end

    local oldPath = "worlds/" .. oldName .. ".lua"
    local newPath = "worlds/" .. sanitizedNewName .. ".lua"

    if oldPath == newPath then print("New name is the same as old name."); return end
    if not love.filesystem.getInfo(oldPath) then print("Original world file not found: " .. oldPath); return end
    if love.filesystem.getInfo(newPath) then print("A world with the new name already exists: " .. newPath); return end

    local content = love.filesystem.read(oldPath)
    if not content then print("Could not read world file for renaming: " .. oldPath); return end

    content = content:gsub('world_name = "' .. oldName:gsub('"', '\"') .. '"', 'world_name = "' .. sanitizedNewName:gsub('"', '\"') .. '"', 1)

    if love.filesystem.write(newPath, content) then
        if love.filesystem.remove(oldPath) then
            print("Renamed world " .. oldName .. " to " .. sanitizedNewName)
            self:load()
        else
            print("Error: Renamed content, but failed to remove old file " .. oldPath)
            love.filesystem.remove(newPath) -- Attempt to clean up
            self:load()
        end
    else
        print("Error writing renamed world file: " .. newPath)
    end
end

function WorldSelectMenu:deleteWorld(worldName)
    local worldPath = "worlds/" .. worldName .. ".lua"
    if love.filesystem.getInfo(worldPath) then
        if love.filesystem.remove(worldPath) then
            print("Deleted world: " .. worldName)
            self:load() -- Reload the world list to reflect the deletion
        else
            print("Error deleting world: " .. worldName)
        end
    else
        print("World not found: " .. worldName)
    end
end

function WorldSelectMenu:confirmDeleteWorld(world)
    self.isNamingWorld = true
    self.namingAction = "delete"
    self.worldNameInput = world.name
    self.originalName = world.name
    love.keyboard.setTextInput(false)
end

function WorldSelectMenu:resize(w,h)
    self:calculateLayout()
    -- Ensure scroll offset is still valid
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, math.max(0, #self.worlds - self.listVisibleItems)))
end

return WorldSelectMenu
