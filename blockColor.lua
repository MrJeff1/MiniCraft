local blockColor = {}

function blockColor.getBlockColor(blockType)
    if blockType == "dirt" then return 0.6, 0.4, 0.2
    elseif blockType == "stone" then return 0.5, 0.5, 0.5
    elseif blockType == "wood" then return 0.4, 0.3, 0.1
    elseif blockType == "grass" then return 0.2, 0.8, 0.2
    elseif blockType == "log" then return 0.35, 0.2, 0.05
    elseif blockType == "leaves" then return 0.1, 0.6, 0.1
    elseif blockType == "coal_ore" then return 0.2, 0.2, 0.2
    elseif blockType == "iron_ore" then return 0.7, 0.4, 0.2
    else return 1, 1, 1 -- Default color (white)
    end
end

return blockColor