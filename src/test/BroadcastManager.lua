-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast
local BinaryBuffer = LGB.internal.class.BinaryBuffer
local BroadcastManager = LGB.internal.class.BroadcastManager
local FrameHandler = LGB.internal.class.FrameHandler
local FlexSizeDataMessage = LGB.internal.class.FlexSizeDataMessage
local StringField = LGB.internal.class.StringField
local ArrayField = LGB.internal.class.ArrayField
local TableField = LGB.internal.class.TableField
local NumericField = LGB.internal.class.NumericField
local PercentageField = LGB.internal.class.PercentageField

Taneth("LibGroupBroadcast", function()
    describe("BroadcastManager", function()
        it("should be able to create a new instance", function()
            local internal = LGB.SetupMockInstance()
            assert.is_true(ZO_Object.IsInstanceOf(internal.broadcastManager, BroadcastManager))
        end)

        it.async("should be able to send and receive a long message", function(done)
            local internal = LGB.SetupMockInstance()
            local manager = internal.broadcastManager

            local sendDataTriggered = 0
            ZO_PreHook(manager, "SendData", function()
                sendDataTriggered = sendDataTriggered + 1
            end)

            local onDataReceivedTriggered = 0
            ZO_PreHook(manager, "OnDataReceived", function()
                onDataReceivedTriggered = onDataReceivedTriggered + 1
            end)

            local outgoingData = { text = string.rep("a", 255) }
            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            assert.is_not_nil(protocol)
            protocol:AddField(StringField:New("text"))
            protocol:OnData(function(unitTag, data)
                assert.same(outgoingData, data)
                assert.equals("player", unitTag)
                assert.equals(10, sendDataTriggered)
                assert.equals(10, onDataReceivedTriggered)
                done()
            end)
            protocol:Finalize()

            assert.is_true(protocol:Send(outgoingData))
        end)

        it.async("should be able to send and receive an array of tables", function(done)
            local internal = LGB.SetupMockInstance()
            internal.gameApiWrapper:SetInCombat(false)

            local outgoingData = {
                test = {
                    { numberA = 0,  numberB = 1,  numberC = 2,  numberD = 3 },
                    { numberA = 4,  numberB = 5,  numberC = 6,  numberD = 7 },
                    { numberA = 8,  numberB = 9,  numberC = 10, numberD = 11 },
                    { numberA = 12, numberB = 13, numberC = 14, numberD = 15 },
                    { numberA = 16, numberB = 17, numberC = 18, numberD = 19 },
                    { numberA = 20, numberB = 21, numberC = 22, numberD = 23 },
                    { numberA = 24, numberB = 25, numberC = 26, numberD = 27 },
                    { numberA = 28, numberB = 29, numberC = 30, numberD = 31 }
                }
            }

            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            protocol:AddField(ArrayField:New(TableField:New("test", {
                NumericField:New("numberA"),
                NumericField:New("numberB"),
                NumericField:New("numberC"),
                NumericField:New("numberD")
            }), { minLength = 1, maxLength = 8 }))
            protocol:OnData(function(unitTag, data)
                assert.same(outgoingData, data)
                assert.equals("player", unitTag)
                done()
            end)
            protocol:Finalize()

            assert.is_true(protocol:Send(outgoingData))
        end)

        it.async("should be able to set multiple different message types in the same broadcast", function(done)
            local internal = LGB.SetupMockInstance()
            local protocolManager = internal.protocolManager

            local received = {
                testEvent1 = false,
                testEvent2 = false,
                test1 = false,
                test2 = false
            }
            local function FinishTest()
                for _, hasReceived in pairs(received) do
                    if not hasReceived then return end
                end
                done()
            end

            local handler = internal.handlerManager:RegisterHandler("test")
            local FireEvent1 = handler:DeclareCustomEvent(0, "testEvent1")
            protocolManager:RegisterForCustomEvent("testEvent1", function(unitTag)
                assert.equals("player", unitTag)
                received.testEvent1 = true
                FinishTest()
            end)

            local FireEvent2 = handler:DeclareCustomEvent(5, "testEvent2")
            protocolManager:RegisterForCustomEvent("testEvent2", function(unitTag)
                assert.equals("player", unitTag)
                received.testEvent2 = true
                FinishTest()
            end)

            local outgoingData1 = {
                text = "hello",
                number = 42
            }
            local outgoingData2 = {
                percentage = 1
            }

            local protocol1 = handler:DeclareProtocol(0, "test1")
            protocol1:AddField(StringField:New("text"))
            protocol1:AddField(NumericField:New("number"))
            protocol1:OnData(function(unitTag, data)
                assert.same(outgoingData1, data)
                assert.equals("player", unitTag)
                received.test1 = true
                FinishTest()
            end)
            assert.is_true(protocol1:Finalize())

            local protocol2 = handler:DeclareProtocol(1, "test2")
            protocol2:AddField(PercentageField:New("percentage"))
            protocol2:OnData(function(unitTag, data)
                assert.same(outgoingData2, data)
                assert.equals("player", unitTag)
                received.test2 = true
                FinishTest()
            end)
            assert.is_true(protocol2:Finalize())

            FireEvent1(outgoingData1)
            FireEvent2(outgoingData2)
            assert.is_true(protocol1:Send(outgoingData1))
            assert.is_true(protocol2:Send(outgoingData2))
        end)

        it.async("should clear queued messages when not in a group", function(done)
            local internal = LGB.SetupMockInstance()
            local manager = internal.broadcastManager

            ZO_PreHook(manager.protocolManager, "ClearQueuedMessages", function()
                done()
            end)

            local outgoingData = { text = string.rep("a", 255) }
            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            assert.is_not_nil(protocol)
            protocol:AddField(StringField:New("text"))
            protocol:OnData(function()
                assert.fail("Should not receive data when not in a group.")
            end)
            protocol:Finalize()

            assert.is_true(protocol:Send(outgoingData))
            internal.gameApiWrapper:SetGrouped(false)
        end)

        it.async("should not send disabled custom events", function(done)
            local internal = LGB.SetupMockInstance()
            local broadcastManager = internal.broadcastManager
            local protocolManager = internal.protocolManager

            local sendDataTriggered = 0
            local received = 0
            local handler = internal.handlerManager:RegisterHandler("test")
            local FireEvent = handler:DeclareCustomEvent(0, "testEvent")
            protocolManager:RegisterForCustomEvent("testEvent", function()
                received = received + 1
                if received == 2 then
                    done()
                end
            end)

            ZO_PostHook(broadcastManager, "SendData", function()
                sendDataTriggered = sendDataTriggered + 1
                if sendDataTriggered == 1 then
                    protocolManager:SetCustomEventEnabled(0, false)
                    assert.is_false(protocolManager:IsCustomEventEnabled(0))
                    FireEvent()
                elseif sendDataTriggered == 2 then
                    protocolManager:SetCustomEventEnabled(0, true)
                    assert.is_true(protocolManager:IsCustomEventEnabled(0))
                    FireEvent()
                end
            end)

            FireEvent()
        end)

        it.async("should not send disabled protocols", function(done)
            local internal = LGB.SetupMockInstance()
            local broadcastManager = internal.broadcastManager
            local protocolManager = internal.protocolManager

            local sendDataTriggered = 0
            local received = {}
            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            assert.is_not_nil(protocol)
            protocol:AddField(NumericField:New("test"))
            protocol:OnData(function(_, data)
                received[#received + 1] = data.test
                if data.test == 3 then
                    assert.equals(3, sendDataTriggered)
                    assert.same({ 1, 3 }, received)
                    done()
                end
            end)
            protocol:Finalize()

            ZO_PostHook(broadcastManager, "SendData", function()
                sendDataTriggered = sendDataTriggered + 1
                if sendDataTriggered == 1 then
                    protocolManager:SetProtocolEnabled(0, false)
                    assert.is_false(protocol:IsEnabled())
                    assert.is_true(protocol:Send({ test = 2 }))
                elseif sendDataTriggered == 2 then
                    protocolManager:SetProtocolEnabled(0, true)
                    assert.is_true(protocol:IsEnabled())
                    assert.is_true(protocol:Send({ test = 3 }))
                end
            end)

            assert.is_true(protocol:IsEnabled())
            assert.is_true(protocol:Send({ test = 1 }))
        end)

        it("should independently reassemble multi-frame messages from different senders", function()
            local internal = LGB.SetupMockInstance()

            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            protocol:AddField(StringField:New("text"))

            local received = {}
            protocol:OnData(function(unitTag, data)
                received[#received + 1] = { unitTag = unitTag, text = data.text }
            end)
            protocol:Finalize()

            -- Construct frames the way a real sender would
            local function makeFrames(text)
                local field = StringField:New("text")
                local data = BinaryBuffer:New(7)
                field:Serialize(data, { text = text })
                local message = FlexSizeDataMessage:New(0, data)

                local frames = {}
                local fh = FrameHandler:New()
                while not message:IsFullySent() do
                    assert.is_true(fh:AddFlexSizeDataMessage(message))
                    frames[#frames + 1] = fh:Serialize():ToUInt32Array()
                    fh:Reset()
                end
                return frames
            end

            local textA = string.rep("a", 100)
            local textB = string.rep("b", 100)
            local framesA = makeFrames(textA)
            local framesB = makeFrames(textB)

            assert.is_true(#framesA > 1)
            assert.is_true(#framesB > 1)

            local gaw = internal.gameApiWrapper
            local maxFrames = math.max(#framesA, #framesB)
            for i = 1, maxFrames do
                if framesA[i] then
                    gaw:OnDataReceived("group1", unpack(framesA[i]))
                end
                if framesB[i] then
                    gaw:OnDataReceived("group2", unpack(framesB[i]))
                end
            end

            assert.equals(2, #received)
            assert.equals("group1", received[1].unitTag)
            assert.equals(textA, received[1].text)
            assert.equals("group2", received[2].unitTag)
            assert.equals(textB, received[2].text)
        end)

        it.async("should be able to send and receive two big messages on the same protocol", function(done)
            local internal = LGB.SetupMockInstance()

            local outgoingA = { text = string.rep("a", 255) }
            local outgoingB = { text = string.rep("b", 255) }
            local received = {}

            local handler = internal.handlerManager:RegisterHandler("test")
            local protocol = handler:DeclareProtocol(0, "test")
            assert.is_not_nil(protocol)
            protocol:AddField(StringField:New("text"))
            protocol:OnData(function(unitTag, data)
                received[#received + 1] = data.text
                if #received == 2 then
                    assert.equals(outgoingA.text, received[1])
                    assert.equals(outgoingB.text, received[2])
                    done()
                end
            end)
            protocol:Finalize({ replaceQueuedMessages = false })

            assert.is_true(protocol:Send(outgoingA))
            assert.is_true(protocol:Send(outgoingB))
        end)
    end)
end)
