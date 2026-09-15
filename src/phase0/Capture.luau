--!strict

local CollectionService = game:GetService("CollectionService")
local ReflectionService = game:GetService("ReflectionService")

local ValueEncoder = require(script.Parent.ValueEncoder)

export type CaptureResult = {
	instances: { any },
	summary: {
		instance_count: number,
		readable_property_count: number,
		capture_gap_count: number,
		unsupported_value_count: number,
		elapsed_seconds: number,
	},
}

local Capture = {}

local function orderedChildren(parent: Instance): { Instance }
	local children = parent:GetChildren()
	table.sort(children, function(left, right)
		if left.Name == right.Name then
			return left.ClassName < right.ClassName
		end
		return left.Name < right.Name
	end)
	return children
end

local function createIdMap(root: Instance): ({ [Instance]: string }, { Instance })
	local ids: { [Instance]: string } = {}
	local ordered = {}

	local function visit(instance: Instance, id: string)
		ids[instance] = id
		table.insert(ordered, instance)

		local siblingsByKey: { [string]: number } = {}
		for _, child in orderedChildren(instance) do
			local key = child.ClassName .. "\0" .. child.Name
			local occurrence = (siblingsByKey[key] or 0) + 1
			siblingsByKey[key] = occurrence
			visit(child, string.format("%s/%s:%s[%d]", id, child.ClassName, child.Name, occurrence))
		end
	end

	visit(root, "/")
	return ids, ordered
end

local function propertyCatalog(className: string): ({ any }, string?)
	local ok, properties = pcall(function()
		return ReflectionService:GetPropertiesOfClass(className)
	end)
	if not ok then
		return {}, tostring(properties)
	end

	table.sort(properties, function(left, right)
		return left.Name < right.Name
	end)
	return properties, nil
end

function Capture.capture(root: Instance): CaptureResult
	local started = os.clock()
	local instanceIds, ordered = createIdMap(root)
	local records = table.create(#ordered)
	local readableCount = 0
	local gapCount = 0
	local unsupportedCount = 0

	for _, instance in ordered do
		local properties = {}
		local gaps = {}
		local catalog, catalogError = propertyCatalog(instance.ClassName)

		if catalogError then
			table.insert(gaps, { property = "*reflection*", error = catalogError })
			gapCount += 1
		end

		for _, reflected in catalog do
			local propertyName = reflected.Name
			local ok, value = pcall(function()
				return (instance :: any)[propertyName]
			end)

			if ok then
				local encoded = ValueEncoder.encode(value, instanceIds)
				properties[propertyName] = encoded
				readableCount += 1
				if type(encoded) == "table" and encoded.unsupported == true then
					unsupportedCount += 1
				end
			else
				table.insert(gaps, { property = propertyName, error = tostring(value) })
				gapCount += 1
			end
		end

		local attributes = {}
		for name, value in instance:GetAttributes() do
			attributes[name] = ValueEncoder.encode(value, instanceIds)
		end

		local tags = CollectionService:GetTags(instance)
		table.sort(tags)
		table.insert(records, {
			id = instanceIds[instance],
			parent_id = if instance.Parent then instanceIds[instance.Parent] else nil,
			name = instance.Name,
			class_name = instance.ClassName,
			properties = properties,
			attributes = attributes,
			tags = tags,
			capture_gaps = gaps,
		})
	end

	return {
		instances = records,
		summary = {
			instance_count = #records,
			readable_property_count = readableCount,
			capture_gap_count = gapCount,
			unsupported_value_count = unsupportedCount,
			elapsed_seconds = os.clock() - started,
		},
	}
end

return Capture
