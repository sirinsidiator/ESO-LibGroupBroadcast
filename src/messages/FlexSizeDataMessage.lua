-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast
local DataMessageBase = LGB.internal.class.DataMessageBase
local BinaryBuffer = LGB.internal.class.BinaryBuffer

--- @class FlexSizeDataMessage : DataMessageBase
local FlexSizeDataMessage = DataMessageBase:Subclass()
LGB.internal.class.FlexSizeDataMessage = FlexSizeDataMessage

local NUM_ID_BITS = 9
local NUM_LENGTH_BITS = 5
local HEADER_BYTES = 2
local MAX_NUM_BYTES = 30

function FlexSizeDataMessage:Initialize(id, data, options)
    DataMessageBase.Initialize(self, id, data, NUM_ID_BITS, nil, options)
    self.isContinued = false
    self.hasContinuation = false
    self.bytesToSend = 0
    self.bytesSent = 0
    self.statusUpdated = false
end

function FlexSizeDataMessage:IsContinuation()
    return self.isContinued
end

function FlexSizeDataMessage:HasContinuation()
    return self.hasContinuation
end

function FlexSizeDataMessage:UpdateStatus(availableBytes)
    availableBytes = math.min(availableBytes, MAX_NUM_BYTES) - HEADER_BYTES
    local remainingBytes = self.data:GetByteLength() - self.bytesSent
    self.isContinued = self.bytesSent > 0
    self.hasContinuation = remainingBytes > availableBytes
    self.bytesToSend = math.min(remainingBytes, availableBytes)
    self.bytesSent = self.bytesSent + self.bytesToSend
    self.statusUpdated = true
end

function FlexSizeDataMessage:GetBytesToSend()
    return HEADER_BYTES + self.bytesToSend
end

function FlexSizeDataMessage:GetSize()
    return HEADER_BYTES + (self.data:GetByteLength() - self.bytesSent)
end

function FlexSizeDataMessage:IsFullySent()
    return self.bytesSent == self.data:GetByteLength()
end

function FlexSizeDataMessage:IsPartiallySent()
    return self.bytesSent > 0 and not self:IsFullySent()
end

function FlexSizeDataMessage:ShouldRequeue()
    return not self:IsFullySent()
end

function FlexSizeDataMessage:CanAppendMessage(message)
    return self.hasContinuation and message.isContinued and self.id == message.id
end

function FlexSizeDataMessage:AppendMessage(message)
    local newBuffer = BinaryBuffer:New(self.data:GetNumBits() + message.data:GetNumBits())
    newBuffer:WriteBuffer(self.data)
    newBuffer:WriteBuffer(message.data)
    self.data = newBuffer
    self.isContinued = true
    self.hasContinuation = message.hasContinuation
end

function FlexSizeDataMessage:Finalize()
    self.data:Rewind()
end

function FlexSizeDataMessage:Serialize(buffer)
    assert(self.statusUpdated, "Tried to serialize flex sized message without updating status first")
    buffer:WriteUInt(self.id, NUM_ID_BITS)
    buffer:WriteUInt(self.bytesToSend - 1, NUM_LENGTH_BITS)
    buffer:WriteBit(self.isContinued)
    buffer:WriteBit(self.hasContinuation)
    local length = self.bytesToSend * 8
    local offset = self.bytesSent * 8 - length + 1
    local availableBits = math.min(self.data:GetNumBits() - (offset - 1), length)
    buffer:WriteBuffer(self.data, availableBits, offset)
    local remainingBits = math.max(0, length - availableBits)
    if remainingBits > 0 then
        buffer:Seek(remainingBits)
    end
end

function FlexSizeDataMessage.Deserialize(buffer)
    local id = buffer:ReadUInt(NUM_ID_BITS)
    local length = buffer:ReadUInt(NUM_LENGTH_BITS) + 1
    local isContinued = buffer:ReadBit(true)
    local hasContinuation = buffer:ReadBit(true)
    local data = buffer:ReadBuffer(length * 8)

    local message = FlexSizeDataMessage:New(id, data)
    message.isContinued = isContinued
    message.hasContinuation = hasContinuation
    return message
end
