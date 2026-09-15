--!strict

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")

local Capture = require(script.Parent.Capture)

local SerializationProbe = {}

local function semanticJson(capture: Capture.CaptureResult): string
	return HttpService:JSONEncode(capture.instances)
end

function SerializationProbe.run(root: Instance): { [string]: any }
	local originalCapture = Capture.capture(root)
	local serializeStarted = os.clock()
	local content = SerializationService:SerializeInstancesAsync({ root })
	local serializeSeconds = os.clock() - serializeStarted

	local deserializeStarted = os.clock()
	local roundTripRoots = SerializationService:DeserializeInstancesAsync(content)
	local deserializeSeconds = os.clock() - deserializeStarted
	assert(#roundTripRoots == 1, "expected exactly one deserialized root")

	local roundTripCapture = Capture.capture(roundTripRoots[1])
	local originalJson = semanticJson(originalCapture)
	local roundTripJson = semanticJson(roundTripCapture)

	for _, roundTripRoot in roundTripRoots do
		roundTripRoot:Destroy()
	end

	return {
		schema_version = 1,
		probe = "studio-native-rbxm-round-trip",
		captured_at_unix = os.time(),
		studio = {
			place_id = game.PlaceId,
			game_id = game.GameId,
		},
		root = {
			name = root.Name,
			class_name = root.ClassName,
		},
		summary = originalCapture.summary,
		round_trip = {
			serialized_bytes = buffer.len(content),
			serialize_seconds = serializeSeconds,
			deserialize_seconds = deserializeSeconds,
			semantic_equal = originalJson == roundTripJson,
			original_capture = originalCapture,
			deserialized_capture = roundTripCapture,
		},
		decision = "UNASSESSED",
	}
end

return SerializationProbe
