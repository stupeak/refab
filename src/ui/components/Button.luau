--!strict

local Button = {}

export type ButtonOptions = {
	text: string,
	height: number?,
	accent: boolean?,
}

function Button.create(options: ButtonOptions): TextButton
	local button = Instance.new("TextButton")
	button.Name = options.text:gsub("%s+", "") .. "Button"
	button.Size = UDim2.new(1, 0, 0, options.height or 34)
	button.BackgroundColor3 = if options.accent then Color3.fromRGB(31, 103, 185) else Color3.fromRGB(56, 58, 64)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansSemibold
	button.Text = options.text
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.TextSize = 16
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	return button
end

return Button
