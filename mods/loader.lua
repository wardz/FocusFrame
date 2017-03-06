local Focus = getglobal("FocusData")
local Loader = CreateFrame("Frame")
Loader.addons = {}

local function debug(str)
    if false then
        DEFAULT_CHAT_FRAME:AddMessage(str)
    end
end

local EventHandler = function()
    if Loader[event] then
        return Loader[event](Loader, arg1)
    end
end

local function FreeLoadedAddons()
    for k, v in pairs(Loader.addons) do
        if not v.onDemand then
            Loader.addons[k] = nil
            debug("delete " .. k)
        else
            if v.hasRan and not v.loaded then
                Loader.addons[k] = nil
                debug("delete " .. k)
            end
        end
    end
end

function Loader:ADDON_LOADED(addonName)
    if Loader.addons[addonName] then
        local success = pcall(Loader.addons[addonName].init, Focus)
        Loader.addons[addonName].loaded = success
        Loader.addons[addonName].hasRan = true

        debug(addonName .. " = " .. (success and "1" or "0"))
    end
end

function Loader:PLAYER_ENTERING_WORLD()
    FreeLoadedAddons()

    -- All registered addons loaded, run cleanup
    if not next(Loader.addons) then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self:SetScript("OnEvent", nil)

        for k, v in pairs(Loader) do
            Loader[k] = nil
        end

        debug("all free")
    end
end

--- Register callback to be ran when ADDON_LOADED event is fired for addonName
-- @tparam string addonName
-- @tparam func callback
-- @tparam[opt=false] bool - True if addon is loaded on demand, and not instantly on login.
function Loader:Register(addonName, callback, onDemand)
    if type(addonName) ~= "string" or type(callback) ~= "function" then
        return error('Usage: Register("name", callbackFunc, false)')
    end

    Loader.addons[addonName] = {
        init = callback,
        loaded = false,
        hasRan = false,
        onDemand = onDemand
    }

    debug("registered " .. addonName)

    -- Trigger event ourselves if addon is already loaded
    if IsAddOnLoaded(addonName) then
        self:ADDON_LOADED(addonName)
    end
end

Loader:RegisterEvent("ADDON_LOADED")
Loader:RegisterEvent("PLAYER_ENTERING_WORLD")
Loader:SetScript("OnEvent", EventHandler)
Loader:Hide()

-- add to global namespace
FocusFrame_Loader = Loader
