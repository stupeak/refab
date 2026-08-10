--!strict

local Checkbox = require(script.Parent.Checkbox)
local AssetDefinition = require(script.Parent.Parent.Parent.core.AssetDefinition)

local AssetList = {}

export type Handle = {
	root: ScrollingFrame,
	render: ({AssetDefinition.AssetDefinition}) -> (),
}

local function statusColor(status: AssetDefinition.AssetStatus): Color3
	if status == "Error" then
		return Color3.fromRGB(227, 88, 88)
	elseif status == "Warning" then
		return Color3.fromRGB(219, 170, 65)
	end
	return Color3.fromRGB(155, 166, 179)
end

function AssetList.create(): Handle
	local root = Instance.new("ScrollingFrame")
	root.Name = "AssetList"
	root.Size = UDim2.new(1, 0, 1, -96)
	root.BackgroundColor3 = Color3.fromRGB(31, 33, 38)
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 8
	root.CanvasSize = UDim2.new()
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = root

	local function clear()
		for _, child in root:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function addEmpty(message: string)
		local label = Instance.new("TextLabel")
		label.Name = "EmptyState"
		label.Size = UDim2.new(1, -16, 0, 44)
		label.BackgroundTransparency = 1
		label.Text = message
		label.TextColor3 = Color3.fromRGB(178, 185, 194)
		label.TextSize = 15
		label.TextWrapped = true
		label.Font = Enum.Font.SourceSans
		label.Parent = root
	end

	local function addRow(asset: AssetDefinition.AssetDefinition, index: number)
		local row = Instance.new("Frame")
		row.Name = "AssetRow"
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -16, 0, if asset.message then 62 else 44)
		row.BackgroundColor3 = Color3.fromRGB(38, 41, 48)
		row.BorderSizePixel = 0
		row.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = row

		local checkbox = Checkbox.create(asset.selected)
		checkbox.root.Position = UDim2.new(0, 10, 0, 11)
		checkbox.root.Parent = row
		checkbox.onChanged:Connect(function(checked: boolean)
			asset.selected = checked
		end)

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Position = UDim2.new(0, 42, 0, 5)
		title.Size = UDim2.new(1, -132, 0, 20)
		title.BackgroundTransparency = 1
		title.Text = asset.name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(244, 246, 248)
		title.TextSize = 16
		title.Font = Enum.Font.SourceSansSemibold
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Parent = row

		local className = Instance.new("TextLabel")
		className.Name = "ClassName"
		className.Position = UDim2.new(1, -86, 0, 5)
		className.Size = UDim2.new(0, 76, 0, 20)
		className.BackgroundTransparency = 1
		className.Text = asset.className
		className.TextXAlignment = Enum.TextXAlignment.Right
		className.TextColor3 = statusColor(asset.status)
		className.TextSize = 14
		className.Font = Enum.Font.SourceSans
		className.TextTruncate = Enum.TextTruncate.AtEnd
		className.Parent = row

		local path = Instance.new("TextLabel")
		path.Name = "Path"
		path.Position = UDim2.new(0, 42, 0, 25)
		path.Size = UDim2.new(1, -52, 0, 18)
		path.BackgroundTransparency = 1
		path.Text = asset.assetPath ~= "" and asset.assetPath or (asset.message or "")
		path.TextXAlignment = Enum.TextXAlignment.Left
		path.TextColor3 = statusColor(asset.status)
		path.TextSize = 13
		path.Font = Enum.Font.SourceSans
		path.TextTruncate = Enum.TextTruncate.AtEnd
		path.Parent = row

		if asset.message and asset.assetPath ~= "" then
			local message = Instance.new("TextLabel")
			message.Name = "Message"
			message.Position = UDim2.new(0, 42, 0, 43)
			message.Size = UDim2.new(1, -52, 0, 16)
			message.BackgroundTransparency = 1
			message.Text = asset.message
			message.TextXAlignment = Enum.TextXAlignment.Left
			message.TextColor3 = statusColor(asset.status)
			message.TextSize = 12
			message.Font = Enum.Font.SourceSans
			message.TextTruncate = Enum.TextTruncate.AtEnd
			message.Parent = row
		end
	end

	return {
		root = root,
		render = function(assets: {AssetDefinition.AssetDefinition})
			clear()
			if #assets == 0 then
				addEmpty("No assets to show.")
				return
			end

			for index, asset in assets do
				addRow(asset, index)
			end
		end,
	}
end

return AssetList
