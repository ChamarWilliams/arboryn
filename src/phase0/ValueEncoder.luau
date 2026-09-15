--!strict

local ValueEncoder = {}

local function components(value: any, names: { string }): { number }
	local output = table.create(#names)
	for index, name in names do
		output[index] = value[name]
	end
	return output
end

function ValueEncoder.encode(value: any, instanceIds: { [Instance]: string }): any
	local kind = typeof(value)

	if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
		return value
	elseif kind == "Instance" then
		local instance = value :: Instance
		return {
			["$type"] = "Instance",
			local_id = instanceIds[instance],
			external_path = if instanceIds[instance] then nil else instance:GetFullName(),
			class_name = instance.ClassName,
		}
	elseif kind == "EnumItem" then
		return { ["$type"] = "EnumItem", value = tostring(value) }
	elseif kind == "BrickColor" then
		return { ["$type"] = "BrickColor", number = value.Number, name = value.Name }
	elseif kind == "Color3" then
		return { ["$type"] = "Color3", value = components(value, { "R", "G", "B" }) }
	elseif kind == "Vector2" then
		return { ["$type"] = "Vector2", value = components(value, { "X", "Y" }) }
	elseif kind == "Vector3" then
		return { ["$type"] = "Vector3", value = components(value, { "X", "Y", "Z" }) }
	elseif kind == "CFrame" then
		return { ["$type"] = "CFrame", value = { value:GetComponents() } }
	elseif kind == "UDim" then
		return { ["$type"] = "UDim", value = components(value, { "Scale", "Offset" }) }
	elseif kind == "UDim2" then
		return {
			["$type"] = "UDim2",
			value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset },
		}
	elseif kind == "Rect" then
		return {
			["$type"] = "Rect",
			value = { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y },
		}
	elseif kind == "NumberRange" then
		return { ["$type"] = "NumberRange", value = components(value, { "Min", "Max" }) }
	elseif kind == "NumberSequence" or kind == "ColorSequence" then
		local points = {}
		for _, point in value.Keypoints do
			table.insert(points, ValueEncoder.encode(point, instanceIds))
		end
		return { ["$type"] = kind, keypoints = points }
	elseif kind == "NumberSequenceKeypoint" then
		return {
			["$type"] = kind,
			value = components(value, { "Time", "Value", "Envelope" }),
		}
	elseif kind == "ColorSequenceKeypoint" then
		return {
			["$type"] = kind,
			time = value.Time,
			color = ValueEncoder.encode(value.Value, instanceIds),
		}
	elseif kind == "PhysicalProperties" then
		return {
			["$type"] = kind,
			value = components(
				value,
				{ "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" }
			),
		}
	elseif kind == "Font" then
		return {
			["$type"] = kind,
			family = value.Family,
			weight = tostring(value.Weight),
			style = tostring(value.Style),
		}
	elseif kind == "Faces" or kind == "Axes" then
		return { ["$type"] = kind, value = tostring(value) }
	elseif kind == "buffer" then
		return { ["$type"] = "buffer", length = buffer.len(value) }
	end

	return { ["$type"] = kind, unsupported = true, display = tostring(value) }
end

return ValueEncoder
