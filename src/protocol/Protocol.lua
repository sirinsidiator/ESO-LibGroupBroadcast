-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast
local FieldBase = LGB.internal.class.FieldBase
local BinaryBuffer = LGB.internal.class.BinaryBuffer
local FixedSizeDataMessage = LGB.internal.class.FixedSizeDataMessage
local FlexSizeDataMessage = LGB.internal.class.FlexSizeDataMessage
local logger = LGB.internal.logger

--[[ doc.lua begin ]] --

--- @docType options
--- @class ProtocolOptions
--- @field isRelevantInCombat boolean? Whether the protocol is relevant in combat.
--- @field replaceQueuedMessages boolean? Whether to replace already queued messages with the same protocol ID when Send is called.

--- @class Protocol
--- @field protected id number
--- @field protected name string
--- @field protected manager ProtocolManager
--- @field protected fields FieldBase[]
--- @field protected fieldsByLabel table<string, FieldBase>
--- @field protected finalized boolean
--- @field protected onDataCallback fun(unitTag: string, data: table)
--- @field protected options ProtocolOptions
--- @field protected New fun(self: Protocol, id: number, name: string, manager: ProtocolManager): Protocol
local Protocol = ZO_InitializingObject:Subclass()
LGB.internal.class.Protocol = Protocol

--- @protected
function Protocol:Initialize(id, name, manager)
    self.id = id
    self.name = name
    self.manager = manager
    self.fields = {}
    self.fieldsByLabel = {}
    self.finalized = false
end

--- Getter for the protocol's ID.
--- @return number id The protocol's ID.
function Protocol:GetId()
    return self.id
end

--- Getter for the protocol's name.
--- @return string name The protocol's name.
function Protocol:GetName()
    return self.name
end

--- Adds a field to the protocol. Fields are serialized in the order they are added.
--- @param field FieldBase The field to add.
--- @return Protocol protocol Returns the protocol for chaining.
function Protocol:AddField(field)
    assert(not self.finalized, "Protocol '" .. self.name .. "' has already been finalized")
    assert(ZO_Object.IsInstanceOf(field, FieldBase), "Field must be an instance of FieldBase")

    local index = #self.fields + 1
    local labels = field:RegisterWithProtocol(index)
    for i = 1, #labels do
        local label = labels[i]
        assert(not self.fieldsByLabel[label], "Field with label " .. label .. " already exists")
        self.fieldsByLabel[label] = field
    end
    self.fields[index] = field

    return self
end

--- Sets the callback to be called when data is received for this protocol.
--- @param callback fun(unitTag: string, data: table) The callback to call when data is received.
--- @return Protocol protocol Returns the protocol for chaining.
function Protocol:OnData(callback)
    assert(not self.finalized, "Protocol '" .. self.name .. "' has already been finalized")
    assert(type(callback) == "function", "Callback must be a function")

    self.onDataCallback = callback
    return self
end

--- Returns whether the protocol has been finalized.
--- @return boolean isFinalized Whether the protocol has been finalized.
function Protocol:IsFinalized()
    return self.finalized
end

--- Finalizes the protocol. This must be called before the protocol can be used to send or receive data.
--- @param options? ProtocolOptions Optional options for the protocol.
function Protocol:Finalize(options)
    if #self.fields == 0 then
        logger:Warn("Protocol '%s' has no fields", self.name)
        return false
    end

    if not self.onDataCallback then
        logger:Warn("Protocol '%s' has no data callback", self.name)
        return false
    end

    local isValid = true
    for i = 1, #self.fields do
        local field = self.fields[i]
        local warnings = field:GetWarnings()
        if #warnings > 0 then
            if isValid then
                logger:Warn("Protocol '%s' has invalid fields:", self.name)
            end
            isValid = false
            logger:Warn("Field '%s' has warnings:", field.label)
            for j = 1, #warnings do
                logger:Warn(warnings[j])
            end
        end
    end
    if not isValid then
        return false
    end

    self.options = ZO_ShallowTableCopy(options or {}, {
        isRelevantInCombat = false,
        replaceQueuedMessages = true
    }) --[[@as ProtocolOptions]]

    local minBits, maxBits = 0, 0
    for i = 1, #self.fields do
        local field = self.fields[i]
        local minFieldBits, maxFieldBits = field:GetNumBitsRange()
        minBits = minBits + minFieldBits
        maxBits = maxBits + maxFieldBits
    end

    local minBytes = minBits == 7 and 2 or (2 + math.ceil(minBits / 8))
    local maxBytes = maxBits == 7 and 2 or (2 + math.ceil(maxBits / 8))
    logger:Debug("Protocol '%s' has been finalized. Expected message size is between %d and %d bytes.", self.name,
        minBytes, maxBytes)

    self.finalized = true
    return true
end

--- Converts the passed values into a message and queues it for sending.
--- @param values table The values to send.
--- @param options? ProtocolOptions Optional options for the message.
--- @return boolean success Whether the message was successfully queued.
function Protocol:Send(values, options)
    assert(self.finalized, "Protocol '" .. self.name .. "' has not been finalized")

    local data = BinaryBuffer:New(7)
    for i = 1, #self.fields do
        if not self.fields[i]:Serialize(data, values) then
            return false
        end
    end

    options = options or {}
    for key, value in pairs(self.options) do
        if options[key] == nil then
            options[key] = value
        end
    end

    local message
    if data:GetNumBits() == 7 then
        message = FixedSizeDataMessage:New(self.id, data, options)
    else
        message = FlexSizeDataMessage:New(self.id, data, options)
    end

    self.manager:QueueDataMessage(message)
    return true
end

--- Internal function to receive data for the protocol.
--- @protected
function Protocol:Receive(unitTag, message)
    assert(self.finalized, "Protocol '" .. self.name .. "' has not been finalized")

    local data = message:GetData()
    local values = {}
    for i = 1, #self.fields do
        self.fields[i]:Deserialize(data, values)
    end

    self.onDataCallback(unitTag, values)
end
