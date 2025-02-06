--- @class LibGroupBroadcast
local LGB = LibGroupBroadcast
local NumericField = LGB.internal.class.NumericField

--- @class PercentageFieldOptions: FieldOptionsBase
--- @field defaultValue number? The default value for the field. Must be between 0 and 1.
--- @field numBits number? The number of bits to use for the percentage.

--- @class PercentageField: NumericField
--- @field New fun(self: PercentageField, label: string, options?: PercentageFieldOptions): PercentageField
local PercentageField = NumericField:Subclass()
LGB.internal.class.PercentageField = PercentageField

function PercentageField:Initialize(label, options)
    options = options or {}
    options.numBits = options.numBits or 7
    options.minValue = 0
    options.maxValue = 1
    options.precision = 1 / (2 ^ options.numBits - 1)

    NumericField.Initialize(self, label, options)
end
