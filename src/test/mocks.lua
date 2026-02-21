-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth or not Taneth.IsExternal() then return end

if not LibAddonMenu2 then
    LibAddonMenu2 = {
        RegisterAddonPanel = function() end,
        RegisterOptionControls = function() end,
    }
end

function IsUnitPlayer(unitTag)
    return unitTag == "player"
end

function IsUnitGrouped()
    return false
end

function GetUnitName(unitTag)
    return unitTag
end

function GetRawUnitName(unitTag)
    return unitTag
end

function GetDisplayName()
    return "@player"
end

function GetUnitDisplayName(unitTag)
    return "@" .. unitTag
end

if RegisterForGroupAddOnDataBroadcastAuthKey then return end

EVENT_GROUP_ADD_ON_DATA_RECEIVED = 131222

GROUP_ADD_ON_DATA_BROADCAST_RESULT_SUCCESS = 0
GROUP_ADD_ON_DATA_BROADCAST_RESULT_INVALID_GROUP = 1
GROUP_ADD_ON_DATA_BROADCAST_RESULT_INVALID_AUTH_KEY = 2
GROUP_ADD_ON_DATA_BROADCAST_RESULT_TOO_LARGE = 3
GROUP_ADD_ON_DATA_BROADCAST_RESULT_ON_COOLDOWN = 4

local recipients = {}
local secretAuthKey = math.random(1, 1000)
local registeredAddon = nil
local lastSendTime = 0
local failOnInvalidGroup = true
local senderTag = "player"

ZO_PostHook(EVENT_MANAGER, "RegisterForEvent", function(self, namespace, event, callback)
    if event == EVENT_GROUP_ADD_ON_DATA_RECEIVED then
        recipients[namespace] = callback
    end
end)

ZO_PostHook(EVENT_MANAGER, "UnregisterForEvent", function(self, namespace, event)
    if event == EVENT_GROUP_ADD_ON_DATA_RECEIVED then
        recipients[namespace] = nil
    end
end)

function RegisterForGroupAddOnDataBroadcastAuthKey(addOnName)
    if not registeredAddon then
        registeredAddon = addOnName
        return secretAuthKey, nil
    else
        return nil, registeredAddon
    end
end

function BroadcastAddOnDataToGroup(authKey, ...)
    if failOnInvalidGroup and not IsUnitGrouped("player") then
        return GROUP_ADD_ON_DATA_BROADCAST_RESULT_INVALID_GROUP
    end

    if authKey ~= secretAuthKey then
        return GROUP_ADD_ON_DATA_BROADCAST_RESULT_INVALID_AUTH_KEY
    end

    if GetGroupAddOnDataBroadcastCooldownRemainingMS() > 0 then
        return GROUP_ADD_ON_DATA_BROADCAST_RESULT_ON_COOLDOWN
    end

    local data = { ... }
    if #data > 8 then
        return GROUP_ADD_ON_DATA_BROADCAST_RESULT_TOO_LARGE
    end

    for i = 1, #data do
        if type(data[i]) ~= "number" then
            error("Invalid data type at index " .. i)
        end
    end

    if #data < 8 then
        for i = #data + 1, 8 do
            data[i] = 0
        end
    end

    EVENT_MANAGER:UnregisterForUpdate("LibGroupBroadcastMockAPI")
    EVENT_MANAGER:RegisterForUpdate("LibGroupBroadcastMockAPI", 0, function()
        EVENT_MANAGER:UnregisterForUpdate("LibGroupBroadcastMockAPI")
        for _, callback in pairs(recipients) do
            callback(EVENT_GROUP_ADD_ON_DATA_RECEIVED, senderTag, unpack(data))
        end
    end)

    lastSendTime = GetGameTimeMilliseconds()

    return GROUP_ADD_ON_DATA_BROADCAST_RESULT_SUCCESS
end

local BROADCAST_COOLDOWN_MS = 1000
function GetGroupAddOnDataBroadcastCooldownRemainingMS()
    return math.max(0, BROADCAST_COOLDOWN_MS - (GetGameTimeMilliseconds() - lastSendTime))
end

function ResetGroupAddOnDataBroadcast()
    lastSendTime = -BROADCAST_COOLDOWN_MS
    EVENT_MANAGER:UnregisterForUpdate("LibGroupBroadcastMockAPI")
end

function SetGroupAddOnDataBroadcastFailOnInvalidGroup(value)
    failOnInvalidGroup = value
end
