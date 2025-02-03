if not Taneth then return end
local LGB = LibGroupBroadcast
local NumericField = LGB.internal.class.NumericField
local BinaryBuffer = LGB.internal.class.BinaryBuffer

Taneth("LibGroupBroadcast", function()
    describe("NumericField", function()
        it("should be able to create a new instance", function()
            local field = NumericField:New("test")
            assert.is_true(ZO_Object.IsInstanceOf(field, NumericField))
        end)

        it("should be a uint32 by default", function()
            local field = NumericField:New("test")
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(32, numBits)
            assert.equals(0, field.minValue)
            assert.equals(0xFFFFFFFF, field.maxValue)
            assert.equals(0xFFFFFFFF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 0xFFFFFFFF))
            assert.is_false(field:Serialize(buffer, -1))
            assert.is_false(field:Serialize(buffer, 0x100000000))
        end)

        it("should be able to set a custom number of bits", function()
            local field = NumericField:New("test", { numBits = 8 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(8, numBits)
            assert.equals(0, field.minValue)
            assert.equals(0xFF, field.maxValue)
            assert.equals(0xFF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 0xFF))
            assert.is_false(field:Serialize(buffer, -1))
            assert.is_false(field:Serialize(buffer, 0x100))
        end)

        it("should be able to set a custom unsigned range", function()
            local field = NumericField:New("test", { numBits = 8, minValue = 1, maxValue = 10 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(8, numBits)
            assert.equals(1, field.minValue)
            assert.equals(10, field.maxValue)
            assert.equals(0xFF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 1))
            assert.is_true(field:Serialize(buffer, 10))
            assert.is_false(field:Serialize(buffer, 0))
            assert.is_false(field:Serialize(buffer, 11))
        end)

        it("should be able to set a custom unsigned range with only a minValue", function()
            local field = NumericField:New("test", { numBits = 4, minValue = 10 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(4, numBits)
            assert.equals(10, field.minValue)
            assert.equals(25, field.maxValue)
            assert.equals(0xF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 10))
            assert.is_true(field:Serialize(buffer, 25))
            assert.is_false(field:Serialize(buffer, 9))
            assert.is_false(field:Serialize(buffer, 26))
        end)

        it("should be able to set a custom unsigned range with only a maxValue", function()
            local field = NumericField:New("test", { numBits = 4, maxValue = 45 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(4, numBits)
            assert.equals(30, field.minValue)
            assert.equals(45, field.maxValue)
            assert.equals(0xF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 30))
            assert.is_true(field:Serialize(buffer, 45))
            assert.is_false(field:Serialize(buffer, 29))
            assert.is_false(field:Serialize(buffer, 46))
        end)

        it("should be able to set a custom signed range", function()
            local field = NumericField:New("test", { numBits = 8, minValue = -10, maxValue = 10 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(8, numBits)
            assert.equals(-10, field.minValue)
            assert.equals(10, field.maxValue)
            assert.equals(0xFF, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, -10))
            assert.is_true(field:Serialize(buffer, 10))
            assert.is_false(field:Serialize(buffer, -11))
            assert.is_false(field:Serialize(buffer, 11))
        end)

        it("should be able to save on bits when using a precision", function()
            local field = NumericField:New("test", { minValue = 0, maxValue = 1000, precision = 100 })
            assert.is_true(field:IsValid())
            local numBits = field:GetNumBitsRange()
            assert.equals(4, numBits)
            assert.equals(0, field.minValue)
            assert.equals(1000, field.maxValue)
            assert.equals(15, field.maxSendValue)

            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 1000))
            assert.is_false(field:Serialize(buffer, -1))
            assert.is_false(field:Serialize(buffer, 1001))
        end)

        it("should be able to serialize and deserialize signed numbers", function()
            local field = NumericField:New("test", { minValue = -100, maxValue = 100 })
            assert.is_true(field:IsValid())
            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, -100))
            assert.is_true(field:Serialize(buffer, -1))
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 1))
            assert.is_true(field:Serialize(buffer, 100))
            buffer:Rewind()
            assert.equals(-100, field:Deserialize(buffer))
            assert.equals(-1, field:Deserialize(buffer))
            assert.equals(0, field:Deserialize(buffer))
            assert.equals(1, field:Deserialize(buffer))
            assert.equals(100, field:Deserialize(buffer))
        end)

        it("should be able to serialize and deserialize a number with a precision", function()
            local field = NumericField:New("test", { minValue = 0, maxValue = 1000, precision = 100 })
            assert.is_true(field:IsValid())
            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 49))
            assert.is_true(field:Serialize(buffer, 50))
            assert.is_true(field:Serialize(buffer, 949))
            assert.is_true(field:Serialize(buffer, 950))
            assert.is_true(field:Serialize(buffer, 1000))
            buffer:Rewind()
            assert.equals(0, field:Deserialize(buffer))
            assert.equals(0, field:Deserialize(buffer))
            assert.equals(100, field:Deserialize(buffer))
            assert.equals(900, field:Deserialize(buffer))
            assert.equals(1000, field:Deserialize(buffer))
            assert.equals(1000, field:Deserialize(buffer))
        end)

        it("should be able to serialize and deserialize a floating point number with a precision", function()
            local field = NumericField:New("test", { minValue = 0, maxValue = 10, precision = 0.1 })
            assert.is_true(field:IsValid())
            local buffer = BinaryBuffer:New(1)
            assert.is_true(field:Serialize(buffer, 0))
            assert.is_true(field:Serialize(buffer, 0.01))
            assert.is_true(field:Serialize(buffer, 0.49))
            assert.is_true(field:Serialize(buffer, 0.5))
            assert.is_true(field:Serialize(buffer, 9.95))
            assert.is_true(field:Serialize(buffer, 10))
            buffer:Rewind()
            assert.equals(0, field:Deserialize(buffer))
            assert.equals(0, field:Deserialize(buffer))
            assert.equals(0.5, field:Deserialize(buffer))
            assert.equals(0.5, field:Deserialize(buffer))
            assert.equals(10, field:Deserialize(buffer))
            assert.equals(10, field:Deserialize(buffer))
        end)

        it(
            "should not create a valid field when the precision increases the range beyond what can be fit into the number of bits",
            function()
                local field = NumericField:New("test", { precision = 0.5 })
                assert.is_false(field:IsValid())
            end)
    end)
end)
