--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerStorage = game:GetService("ServerStorage")

local FIXTURE_NAME = "ArborynPhase0Fixture"

local FixtureBuilder = {}

local function finishRecording(identifier: string?, operation: Enum.FinishRecordingOperation)
	if identifier then
		ChangeHistoryService:FinishRecording(identifier, operation)
	end
end

function FixtureBuilder.build(): Model
	local existing = ServerStorage:FindFirstChild(FIXTURE_NAME)
	if existing then
		assert(existing:IsA("Model"), FIXTURE_NAME .. " exists but is not a Model")
		return existing
	end

	local recording = ChangeHistoryService:TryBeginRecording(
		"ArborynPhase0Fixture",
		"Build Arboryn Phase 0 fixture"
	)
	local ok, result = pcall(function()
		local fixture = Instance.new("Model")
		fixture.Name = FIXTURE_NAME
		fixture:SetAttribute("ArborynFixtureVersion", 1)

		local container = Instance.new("Folder")
		container.Name = "Container"
		container.Parent = fixture

		local anchor = Instance.new("Part")
		anchor.Name = "Anchor"
		anchor.Anchored = true
		anchor.Color = Color3.fromRGB(40, 155, 255)
		anchor.Material = Enum.Material.Neon
		anchor.Size = Vector3.new(3, 1, 2)
		anchor.CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(25), 0)
		anchor:SetAttribute("Health", 100)
		anchor:SetAttribute("Owner", "Phase0")
		CollectionService:AddTag(anchor, "ArborynFixture")
		anchor.Parent = container

		local second = anchor:Clone()
		second.Name = "Target"
		second.Color = Color3.fromRGB(255, 170, 40)
		second.CFrame = CFrame.new(5, 4, 0)
		second.Parent = container

		local attachment0 = Instance.new("Attachment")
		attachment0.Name = "BeamStart"
		attachment0.Parent = anchor

		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "BeamEnd"
		attachment1.Parent = second

		local beam = Instance.new("Beam")
		beam.Name = "InternalReferenceBeam"
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Color = ColorSequence.new(anchor.Color, second.Color)
		beam.Width0 = 0.25
		beam.Width1 = 0.5
		beam.Parent = anchor

		local externalReference = Instance.new("ObjectValue")
		externalReference.Name = "ExternalReference"
		externalReference.Value = workspace.Terrain
		externalReference.Parent = container

		local gui = Instance.new("SurfaceGui")
		gui.Name = "UserInterface"
		gui.Adornee = anchor
		gui.Parent = container

		local label = Instance.new("TextLabel")
		label.Name = "Status"
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "Arboryn Phase 0"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
		label.Parent = gui

		local scriptFixture = Instance.new("Script")
		scriptFixture.Name = "FixtureScript"
		scriptFixture.Enabled = false
		scriptFixture.Parent = container
		ScriptEditorService:UpdateSourceAsync(scriptFixture, function()
			return "-- Phase 0 source fixture\nreturn 'arboryn'\n"
		end)

		fixture.Parent = ServerStorage
		return fixture
	end)

	if not ok then
		finishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		error(result)
	end

	finishRecording(recording, Enum.FinishRecordingOperation.Commit)
	return result :: Model
end

return FixtureBuilder
