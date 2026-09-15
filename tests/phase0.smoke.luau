local ReflectionService = game:GetService("ReflectionService")
local SerializationService = game:GetService("SerializationService")

local reflectedProperties = ReflectionService:GetPropertiesOfClass("Part")
assert(#reflectedProperties > 0, "ReflectionService returned no Part properties")

local root = Instance.new("Model")
root.Name = "ArborynSmokeRoot"

local part = Instance.new("Part")
part.Name = "KnownPart"
part.Anchored = true
part:SetAttribute("Fixture", true)
part.Parent = root

local content = SerializationService:SerializeInstancesAsync({ root })
assert(buffer.len(content) > 0, "SerializationService returned an empty buffer")

local restored = SerializationService:DeserializeInstancesAsync(content)
assert(#restored == 1, "expected one restored root")
assert(restored[1].Name == root.Name, "root name did not survive serialization")

local restoredPart = restored[1]:FindFirstChild("KnownPart")
assert(restoredPart ~= nil and restoredPart:IsA("Part"), "part did not survive serialization")
assert(restoredPart.Anchored, "property did not survive serialization")
assert(restoredPart:GetAttribute("Fixture") == true, "attribute did not survive serialization")

root:Destroy()
for _, instance in restored do
	instance:Destroy()
end

print(
	string.format(
		"ARBORYN_PHASE0_SMOKE_OK reflected=%d serialized_bytes=%d",
		#reflectedProperties,
		buffer.len(content)
	)
)
