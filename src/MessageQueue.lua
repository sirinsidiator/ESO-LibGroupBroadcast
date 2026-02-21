-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast

local function byTimeAddedDesc(a, b)
    return a:GetLastQueueId() > b:GetLastQueueId()
end

local function bySizeDescAndTimeAddedDesc(a, b)
    local aSize = a:GetSize()
    local bSize = b:GetSize()
    if aSize == bSize then
        return a:GetLastQueueId() > b:GetLastQueueId()
    end
    return aSize > bSize
end

--[[ doc.lua begin ]] --

--- @class MessageQueue
--- @field New fun(self: MessageQueue): MessageQueue
local MessageQueue = ZO_InitializingObject:Subclass()
LGB.internal.class.MessageQueue = MessageQueue

function MessageQueue:Initialize()
    self.nextId = 1
    self.messages = {}
end

function MessageQueue:Clear(reason)
    for i = #self.messages, 1, -1 do
        self.messages[i]:SetDequeued(reason or "cleared")
        self.messages[i] = nil
    end
end

--- @param message DataMessageBase
function MessageQueue:EnqueueMessage(message)
    if message:ShouldDeleteQueuedMessages() then
        self:DeleteMessagesByProtocolId(message:GetId())
    end

    message:SetQueued(self.nextId)
    self.messages[#self.messages + 1] = message
    self.nextId = self.nextId + 1
end

function MessageQueue:DequeueMessage(i)
    if not i then i = #self.messages end
    if not self.messages[i] then return end

    local message = table.remove(self.messages, i)
    message:SetDequeued("dequeued")
    return message
end

--- @param protocolId number
function MessageQueue:DeleteMessagesByProtocolId(protocolId, reason)
    for i = #self.messages, 1, -1 do
        if self.messages[i]:GetId() == protocolId then
            local message = table.remove(self.messages, i)
            message:SetDequeued(reason or "deleted")
        end
    end
end

function MessageQueue:GetSize()
    return #self.messages
end

function MessageQueue:GetPartiallySentIds()
    local ids
    for _, message in ipairs(self.messages) do
        if message:IsPartiallySent() then
            if not ids then ids = {} end
            ids[message:GetId()] = true
        end
    end
    return ids
end

function MessageQueue:HasRelevantMessages(inCombat)
    if inCombat then
        for _, message in ipairs(self.messages) do
            if message:IsRelevantInCombat() then
                return true
            end
        end
        return false
    else
        return #self.messages > 0
    end
end

function MessageQueue:GetOldestRelevantMessage(inCombat, partiallySentIds)
    if #self.messages == 0 then return end

    table.sort(self.messages, byTimeAddedDesc)

    if inCombat then
        for i = #self.messages, 1, -1 do
            local message = self.messages[i]
            if message:IsRelevantInCombat() and not message:IsBlockedByPartiallySent(partiallySentIds) then
                return self:DequeueMessage(i)
            end
        end
    end

    for i = #self.messages, 1, -1 do
        if not self.messages[i]:IsBlockedByPartiallySent(partiallySentIds) then
            return self:DequeueMessage(i)
        end
    end
end

function MessageQueue:GetNextRelevantEntry(inCombat, partiallySentIds)
    if #self.messages == 0 then return end

    table.sort(self.messages, bySizeDescAndTimeAddedDesc)

    if inCombat then
        for i = #self.messages, 1, -1 do
            if self.messages[i]:IsRelevantInCombat() and not self.messages[i]:IsBlockedByPartiallySent(partiallySentIds) then
                return self:DequeueMessage(i)
            end
        end
    end

    for i = #self.messages, 1, -1 do
        if not self.messages[i]:IsBlockedByPartiallySent(partiallySentIds) then
            return self:DequeueMessage(i)
        end
    end
end

function MessageQueue:GetNextRelevantEntryWithExactSize(size, inCombat, partiallySentIds)
    if #self.messages == 0 then return end

    table.sort(self.messages, bySizeDescAndTimeAddedDesc)

    if inCombat then
        for i = #self.messages, 1, -1 do
            local message = self.messages[i]
            if message:IsRelevantInCombat() and message:GetSize() == size and not message:IsBlockedByPartiallySent(partiallySentIds) then
                return self:DequeueMessage(i)
            end
        end
    end

    for i = #self.messages, 1, -1 do
        local message = self.messages[i]
        if message:GetSize() == size and not message:IsBlockedByPartiallySent(partiallySentIds) then
            return self:DequeueMessage(i)
        end
    end
end
