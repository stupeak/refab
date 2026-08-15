--!strict

local Checkbox = {}

export type CheckboxHandle = {
	root: TextButton,
	setChecked: (boolean) -> (),
	getChecked: () -> boolean,
	onChanged: RBXScriptSignal,
}

function Checkbox.create(initialChecked: boolean): CheckboxHandle
	local checked = initialChecked
	local changed = Instance.new("BindableEvent")

	local root = Instance.new("TextButton")
	root.Name = "Checkbox"
	root.Size = UDim2.new(0, 16, 0, 16)
	root.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	root.BorderColor3 = Color3.fromRGB(145, 145, 145)
	root.TextColor3 = Color3.fromRGB(36, 132, 82)
	root.TextSize = 12
	root.Font = Enum.Font.SourceSansBold
	root.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(120, 120, 120)
	stroke.Thickness = 1
	stroke.Parent = root

	local function render()
		root.Text = if checked then "✓" else ""
		root.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		root.BorderColor3 = Color3.fromRGB(145, 145, 145)
		stroke.Color = Color3.fromRGB(120, 120, 120)
		stroke.Thickness = 1
	end

	root.MouseButton1Click:Connect(function()
		checked = not checked
		render()
		changed:Fire(checked)
	end)

	render()

	return {
		root = root,
		setChecked = function(value: boolean)
			checked = value
			render()
		end,
		getChecked = function()
			return checked
		end,
		onChanged = changed.Event,
	}
end

return Checkbox
