--!strict

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local FixtureBuilder = require(script.phase0.FixtureBuilder)
local SerializationProbe = require(script.phase0.SerializationProbe)

local TOOLBAR_NAME = "Arboryn"
local SETTING_KEY = "ArborynPhase0LatestReport"

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local button =
	toolbar:CreateButton("Phase 0 Probe", "Open the Arboryn capture-fidelity harness", "")
local widget = plugin:CreateDockWidgetPluginGuiAsync(
	"ArborynPhase0",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 380, 280, 300, 220)
)
widget.Title = "Arboryn — Phase 0"

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundColor3 = Color3.fromRGB(24, 26, 31)
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local function makeLabel(text: string, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSans
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 232, 237)
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, 0, 0, height)
	label.Parent = root
	return label
end

local function makeButton(text: string): TextButton
	local control = Instance.new("TextButton")
	control.AutoButtonColor = true
	control.BackgroundColor3 = Color3.fromRGB(53, 94, 189)
	control.BorderSizePixel = 0
	control.Font = Enum.Font.BuilderSansBold
	control.Text = text
	control.TextColor3 = Color3.new(1, 1, 1)
	control.TextSize = 14
	control.Size = UDim2.new(1, 0, 0, 36)
	control.Parent = root
	return control
end

makeLabel("Capture fidelity must be measured before merge work begins.", 42)
local status = makeLabel("Ready. Build the controlled fixture or select one root instance.", 54)
local buildFixture = makeButton("Build controlled fixture")
local runProbe = makeButton("Run selected-root round trip")

local function setStatus(message: string)
	status.Text = message
	print("[Arboryn Phase 0] " .. message)
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

buildFixture.Activated:Connect(function()
	local ok, result = pcall(FixtureBuilder.build)
	if not ok then
		setStatus("Fixture failed: " .. tostring(result))
		return
	end

	Selection:Set({ result :: Instance })
	setStatus("Fixture ready in ServerStorage and selected.")
end)

runProbe.Activated:Connect(function()
	local selected = Selection:Get()
	if #selected ~= 1 then
		setStatus("Select exactly one root instance before running the probe.")
		return
	end

	setStatus("Running probe; Studio may pause while properties are inspected.")
	local ok, result = pcall(SerializationProbe.run, selected[1])
	if not ok then
		setStatus("Probe failed: " .. tostring(result))
		return
	end

	local report = result :: { [string]: any }
	plugin:SetSetting(SETTING_KEY, report)
	print(HttpService:JSONEncode(report))
	setStatus(
		string.format(
			"Complete: %d instances, %d readable properties, %d gaps, round trip %s.",
			report.summary.instance_count,
			report.summary.readable_property_count,
			report.summary.capture_gap_count,
			if report.round_trip.semantic_equal then "matched" else "differed"
		)
	)
end)
