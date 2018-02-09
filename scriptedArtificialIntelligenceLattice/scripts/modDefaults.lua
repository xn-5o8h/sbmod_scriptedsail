local modDefaultsOldInit = init

function init()
    message.setHandler("getDefaults", function(_,_,modName,startingDefaults)
        local currentDefaults = status.statusProperty(modName.."Defaults")
        if currentDefaults == nil then
            --sb.logInfo("Setting initial starter defaults for mod "..modName.." to "..sb.printJson(initialDefaults))
            status.setStatusProperty(modName.."Defaults",defaults)
            return startingDefaults
        end
        return currentDefaults
    end)

    message.setHandler("setDefaults", function(_,_,modName,newDefaults)
        --sb.logInfo("Setting defaults for mod "..modName.." to "..sb.printJson(newDefaults))
        status.setStatusProperty(modName.."Defaults",newDefaults)
    end)

    modDefaultsOldInit()
end