-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

local authKey, addonName = RegisterForGroupAddOnDataBroadcastAuthKey("LibGroupBroadcast")
if not authKey then
    error("Data broadcast auth key has already been claimed by " .. addonName)
end

--- @docType hidden
--- @class LibGroupBroadcastInternal
--- @field logger LibDebugLogger
--- @field callbackManager ZO_CallbackObject
--- @field class table
--- @field handlers table
--- @field authKey number
--- @field gameApiWrapper GameApiWrapper
--- @field dataMessageQueue MessageQueue
--- @field handlerManager HandlerManager
--- @field protocolManager ProtocolManager
--- @field broadcastManager BroadcastManager
local internal = {
    logger = LibDebugLogger:Create("LibGroupBroadcast"),
    callbackManager = ZO_CallbackObject:New(),
    class = {},
    handlers = {},
    authKey = authKey,
}

--- @class LibGroupBroadcast
--- @field private internal LibGroupBroadcastInternal
LibGroupBroadcast = {
    internal = internal
}

local function SetupInstance(instance)
    instance.dataMessageQueue = internal.class.MessageQueue:New()
    instance.protocolManager = internal.class.ProtocolManager:New(instance.callbackManager, instance.dataMessageQueue)
    instance.handlerManager = internal.class.HandlerManager:New(instance.protocolManager)
    instance.broadcastManager = internal.class.BroadcastManager:New(instance.gameApiWrapper, instance.protocolManager,
        instance.callbackManager, instance.dataMessageQueue)
end

--[[ doc.lua begin ]] --
--- @docType hidden
--- @class LibGroupBroadcastMockInstance : LibGroupBroadcast
--- @field callbackManager ZO_CallbackObject
--- @field gameApiWrapper MockGameApiWrapper
--- @field dataMessageQueue MessageQueue
--- @field handlerManager HandlerManager
--- @field protocolManager ProtocolManager
--- @field broadcastManager BroadcastManager
--[[ doc.lua end ]] --

--- @return LibGroupBroadcastMockInstance
function internal.SetupMockInstance()
    local callbackManager = ZO_CallbackObject:New()
    local instance = setmetatable({
        callbackManager = callbackManager,
        gameApiWrapper = internal.class.MockGameApiWrapper:New(callbackManager),
    }, { __index = LibGroupBroadcast })
    SetupInstance(instance)

    function instance:RegisterHandler(...)
        return instance.handlerManager:RegisterHandler(...)
    end

    function instance:GetHandlerApi(...)
        return instance.handlerManager:GetHandlerApi(...)
    end

    function instance:RegisterForCustomEvent(...)
        return instance.protocolManager:RegisterForCustomEvent(...)
    end

    function instance:UnregisterForCustomEvent(...)
        return instance.protocolManager:UnregisterForCustomEvent(...)
    end

    return instance --[[@as LibGroupBroadcastMockInstance]]
end

--- @private
function LibGroupBroadcast:Initialize()
    internal.gameApiWrapper = internal.class.GameApiWrapper:New(authKey, "LibGroupBroadcast", internal.callbackManager)
    SetupInstance(internal)
    internal.authKey = nil
    self.internal = nil
    self.Initialize = nil
end
