-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast
local MessageBase = LGB.internal.class.MessageBase

--- @class DataMessageBase : MessageBase
local DataMessageBase = MessageBase:Subclass()
LGB.internal.class.DataMessageBase = DataMessageBase

function DataMessageBase:Initialize(id, data, idBits, dataBits, options)
    MessageBase.Initialize(self, id, data, idBits, dataBits)
    self.options = options or {}
    self.queueHistory = {}
end

function DataMessageBase:SetQueued(entryId)
    self.queueHistory[#self.queueHistory + 1] = {
        id = entryId,
        added = GetGameTimeMilliseconds(),
        status = "queued"
    }
end

function DataMessageBase:SetDequeued(reason)
    local entry = self.queueHistory[#self.queueHistory]
    if entry then
        entry.removed = GetGameTimeMilliseconds()
        entry.status = reason
    end
end

function DataMessageBase:GetLastQueueId()
    local history = self.queueHistory[#self.queueHistory]
    if history then
        return history.id
    end
    return 0
end

function DataMessageBase:IsRelevantInCombat()
    return self.options.isRelevantInCombat == true
end

function DataMessageBase:ShouldDeleteQueuedMessages()
    return self.options.replaceQueuedMessages == true
end

function DataMessageBase:IsPartiallySent()
    return false
end

function DataMessageBase:ShouldRequeue()
    return false
end

DataMessageBase:MUST_IMPLEMENT("GetSize")
