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
	root.Size = UDim2.new(0, 22, 0, 22)
	root.BackgroundColor3 = Color3.fromRGB(42, 45, 52)
	root.BorderColor3 = Color3.fromRGB(94, 100, 112)
	root.TextColor3 = Color3.fromRGB(255, 255, 255)
	root.TextSize = 16
	root.Font = Enum.Font.SourceSansBold
	root.AutoButtonColor = true

	local function render()
		root.Text = if checked then "X" else ""
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
