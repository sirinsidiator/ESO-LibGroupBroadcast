local LGB = LibGroupBroadcast
local BinaryBuffer = LGB.internal.class.BinaryBuffer
local logger = LGB.internal.logger

local GameApiWrapper = ZO_InitializingObject:Subclass()
LGB.internal.class.GameApiWrapper = GameApiWrapper

local BROADCAST_NUM_BITS = 32 * 8
local BROADCAST_SEND_DELAY_MS = 500

local keyVault = {}

function GameApiWrapper:Initialize(authKey, namespace, callbackManager)
    keyVault[self] = authKey
    self.callbackManager = callbackManager

    if namespace then
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_GROUP_ADD_ON_DATA_RECEIVED, function(_, senderTag, ...)
            self:OnDataReceived(senderTag, ...)
        end)
    end
end

function GameApiWrapper:GetCooldown()
    return GetGroupAddOnDataBroadcastCooldownRemainingMS()
end

function GameApiWrapper:GetInitialSendDelay()
    return BROADCAST_SEND_DELAY_MS
end

function GameApiWrapper:IsInCombat()
    return IsUnitInCombat("player")
end

function GameApiWrapper:BroadcastData(buffer)
    local values = buffer:ToUInt32Array()
    return BroadcastAddOnDataToGroup(keyVault[self], unpack(values))
end

function GameApiWrapper:OnDataReceived(unitTag, ...)
    local data = BinaryBuffer.FromUInt32Values(BROADCAST_NUM_BITS, ...)
    logger:Debug("received data from %s (%s): %s", GetUnitName(unitTag), unitTag, data:ToHexString())
    self.callbackManager:FireCallbacks("OnDataReceived", unitTag, data)
end
