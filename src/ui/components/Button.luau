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
	button.BackgroundColor3 = if options.accent then Color3.fromRGB(0, 120, 215) else Color3.fromRGB(242, 242, 242)
	button.BorderColor3 = if options.accent then Color3.fromRGB(0, 100, 185) else Color3.fromRGB(190, 190, 190)
	button.BorderSizePixel = 1
	button.Font = Enum.Font.SourceSansSemibold
	button.Text = options.text
	button.TextColor3 = if options.accent then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(35, 35, 35)
	button.TextSize = 16
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	return button
end

return Button
