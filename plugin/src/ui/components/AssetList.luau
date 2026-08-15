--!strict

local StudioService = game:GetService("StudioService")

local Checkbox = require(script.Parent.Checkbox)
local AssetDefinition = require(script.Parent.Parent.Parent.core.AssetDefinition)

local AssetList = {}

local PRIMARY_TEXT_SIZE = 14
local SECONDARY_TEXT_SIZE = 12
local BADGE_TEXT_SIZE = 10

export type Handle = {
	root: ScrollingFrame,
	render: ({AssetDefinition.AssetDefinition}) -> (),
}

local function statusColor(status: AssetDefinition.AssetStatus): Color3
	if status == "Error" then
		return Color3.fromRGB(176, 82, 32)
	elseif status == "New" then
		return Color3.fromRGB(36, 132, 82)
	elseif status == "Changed" then
		return Color3.fromRGB(180, 128, 24)
	elseif status == "Warning" then
		return Color3.fromRGB(150, 98, 32)
	end
	return Color3.fromRGB(90, 90, 90)
end

local function statusBackground(status: AssetDefinition.AssetStatus): Color3
	if status == "New" then
		return Color3.fromRGB(232, 247, 238)
	elseif status == "Changed" then
		return Color3.fromRGB(255, 247, 222)
	elseif status == "Error" then
		return Color3.fromRGB(255, 240, 226)
	end
	return Color3.fromRGB(250, 250, 250)
end

local function displayPath(asset: AssetDefinition.AssetDefinition): string
	local path = asset.assetPath
	if path == "" then
		return asset.message or ""
	end
	if path:sub(1, 7) ~= "assets/" then
		path = "assets/" .. path
	end
	return path
end

local function secondaryText(asset: AssetDefinition.AssetDefinition): string
	if asset.assetPath == "" then
		return asset.message or ""
	end
	if asset.status == "Error" or asset.status == "Warning" then
		return asset.message or displayPath(asset)
	end
	return displayPath(asset)
end

local function splitPath(path: string): {string}
	local parts = {}
	for part in path:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

local function classNameFromFolderPath(path: string): string
	local serviceName = path:match("^assets/([^/]+)$")
	if serviceName then
		return serviceName
	end
	return "Folder"
end

local function classNameFromAsset(asset: AssetDefinition.AssetDefinition): string
	if asset.className ~= "rbxm" and asset.className ~= "rbxmx" and asset.className ~= "" then
		return asset.className
	end

	local rootName = displayPath(asset):match("^assets/([^/]+)/")
	if rootName == "StarterGui" then
		return "ScreenGui"
	elseif rootName == "StarterPack" then
		return "Tool"
	elseif rootName == "MaterialService" then
		return "MaterialVariant"
	elseif rootName == "SoundService" then
		return "Sound"
	elseif rootName == "Lighting" then
		return "Sky"
	end

	return "Model"
end

local function applyClassIcon(icon: ImageLabel, className: string)
	local ok, iconInfo = pcall(function()
		return StudioService:GetClassIcon(className)
	end)
	if not ok or typeof(iconInfo) ~= "table" then
		icon.Visible = false
		return
	end

	local info = iconInfo :: any
	if typeof(info.Image) ~= "string" or info.Image == "" then
		icon.Visible = false
		return
	end

	icon.Image = info.Image
	icon.ImageRectOffset = info.ImageRectOffset or Vector2.zero
	icon.ImageRectSize = info.ImageRectSize or Vector2.zero
	icon.Visible = true
end

local function createClassIcon(className: string, parent: Instance): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "ClassIcon"
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	applyClassIcon(icon, className)
	return icon
end

type TreeNode = {
	name: string,
	path: string,
	children: {[string]: TreeNode},
	childNames: {string},
	assets: {AssetDefinition.AssetDefinition},
}

local function collectNodeAssets(node: TreeNode, output: {AssetDefinition.AssetDefinition})
	for _, asset in node.assets do
		table.insert(output, asset)
	end
	for _, childName in node.childNames do
		collectNodeAssets(node.children[childName], output)
	end
end

local function selectableAssets(assets: {AssetDefinition.AssetDefinition}): {AssetDefinition.AssetDefinition}
	local selectable = {}
	for _, asset in assets do
		if asset.status ~= "Error" then
			table.insert(selectable, asset)
		end
	end
	return selectable
end

local function allSelected(assets: {AssetDefinition.AssetDefinition}): boolean
	local selectable = selectableAssets(assets)
	if #selectable == 0 then
		return false
	end

	for _, asset in selectable do
		if not asset.selected then
			return false
		end
	end

	return true
end

local function statusRank(status: AssetDefinition.AssetStatus): number
	if status == "Error" then
		return 5
	elseif status == "Changed" then
		return 4
	elseif status == "New" then
		return 3
	elseif status == "Warning" then
		return 2
	end
	return 1
end

local function statusBadgeText(status: AssetDefinition.AssetStatus): string
	if status == "New" then
		return "NEW"
	elseif status == "Changed" then
		return "CHANGED"
	elseif status == "Error" then
		return "ISSUE"
	elseif status == "Warning" then
		return "CHECK"
	end
	return "CLEAN"
end

function AssetList.create(emptyMessage: string?): Handle
	local collapsed: {[string]: boolean} = {}
	local currentAssets: {AssetDefinition.AssetDefinition} = {}

	local root = Instance.new("ScrollingFrame")
	root.Name = "AssetList"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	root.BorderColor3 = Color3.fromRGB(205, 205, 205)
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
		label.TextColor3 = Color3.fromRGB(90, 90, 90)
		label.TextSize = 15
		label.TextWrapped = true
		label.Font = Enum.Font.SourceSans
		label.Parent = root
	end

	local function addFolderRow(name: string, path: string, index: number, depth: number, folderStatus: AssetDefinition.AssetStatus, nodeAssets: {AssetDefinition.AssetDefinition}, render: () -> ())
		local header = Instance.new("TextButton")
		header.Name = "TreeFolder"
		header.LayoutOrder = index
		header.Size = UDim2.new(1, -16, 0, 24)
		header.BackgroundColor3 = statusBackground(folderStatus)
		header.BorderColor3 = statusColor(folderStatus)
		header.BorderSizePixel = 1
		header.AutoButtonColor = true
		header.Text = ""
		header.Parent = root

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, 8)
		headerCorner.Parent = header

		local indent = math.min(depth, 7) * 16

		local stripe = Instance.new("Frame")
		stripe.Name = "StatusStripe"
		stripe.Size = UDim2.new(0, 4, 1, 0)
		stripe.BackgroundColor3 = statusColor(folderStatus)
		stripe.BorderSizePixel = 0
		stripe.Parent = header

		local checkbox = Checkbox.create(allSelected(nodeAssets))
		checkbox.root.Position = UDim2.new(0, 10 + indent, 0.5, -8)
		checkbox.root.Parent = header
		checkbox.onChanged:Connect(function(checked: boolean)
			for _, asset in selectableAssets(nodeAssets) do
				asset.selected = checked
			end
			render()
		end)

		local arrow = Instance.new("TextLabel")
		arrow.Name = "Arrow"
		arrow.Position = UDim2.new(0, 34 + indent, 0, 0)
		arrow.Size = UDim2.new(0, 16, 1, 0)
		arrow.BackgroundTransparency = 1
		arrow.Text = if collapsed[path] then ">" else "v"
		arrow.TextXAlignment = Enum.TextXAlignment.Left
		arrow.TextColor3 = Color3.fromRGB(80, 80, 80)
		arrow.TextSize = 12
		arrow.Font = Enum.Font.SourceSansSemibold
		arrow.Parent = header

		local icon = createClassIcon(classNameFromFolderPath(path), header)
		icon.Position = UDim2.new(0, 50 + indent, 0.5, -8)

		local label = Instance.new("TextLabel")
		label.Name = "FolderName"
		label.Position = UDim2.new(0, 72 + indent, 0, 0)
		label.Size = UDim2.new(1, -140 - indent, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = name
		header.TextXAlignment = Enum.TextXAlignment.Left
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(35, 35, 35)
		label.TextSize = PRIMARY_TEXT_SIZE
		label.Font = Enum.Font.SourceSansSemibold
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = header

		local badge = Instance.new("TextLabel")
		badge.Name = "StatusBadge"
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -8, 0.5, 0)
		badge.Size = UDim2.new(0, 56, 0, 16)
		badge.BackgroundColor3 = statusColor(folderStatus)
		badge.BorderSizePixel = 0
		badge.Text = statusBadgeText(folderStatus)
		badge.TextColor3 = Color3.fromRGB(255, 255, 255)
		badge.TextSize = BADGE_TEXT_SIZE
		badge.Font = Enum.Font.SourceSansBold
		badge.Parent = header

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 8)
		badgeCorner.Parent = badge

		header.MouseButton1Click:Connect(function()
			collapsed[path] = not collapsed[path]
			render()
		end)
	end

	local function addRow(asset: AssetDefinition.AssetDefinition, index: number, depth: number, render: () -> ())
		local row = Instance.new("TextButton")
		row.Name = "AssetRow"
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -16, 0, 44)
		row.BackgroundColor3 = statusBackground(asset.status)
		row.BorderColor3 = statusColor(asset.status)
		row.BorderSizePixel = 1
		row.AutoButtonColor = true
		row.Text = ""
		row.Parent = root

		local stripe = Instance.new("Frame")
		stripe.Name = "StatusStripe"
		stripe.Size = UDim2.new(0, 5, 1, 0)
		stripe.BackgroundColor3 = statusColor(asset.status)
		stripe.BorderSizePixel = 0
		stripe.Parent = row

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local checkbox = Checkbox.create(asset.selected)
		local indent = math.min(depth, 5) * 14
		checkbox.root.Position = UDim2.new(0, 10 + indent, 0, 14)
		checkbox.root.Parent = row
		checkbox.onChanged:Connect(function(checked: boolean)
			asset.selected = checked
			render()
		end)

		row.MouseButton1Click:Connect(function()
			asset.selected = not asset.selected
			checkbox.setChecked(asset.selected)
			render()
		end)

		local icon = createClassIcon(classNameFromAsset(asset), row)
		icon.Position = UDim2.new(0, 38 + indent, 0, 7)

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Position = UDim2.new(0, 60 + indent, 0, 5)
		title.Size = UDim2.new(1, -128 - indent, 0, 20)
		title.BackgroundTransparency = 1
		title.Text = asset.name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(35, 35, 35)
		title.TextSize = PRIMARY_TEXT_SIZE
		title.Font = Enum.Font.SourceSansSemibold
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Parent = row

		local className = Instance.new("TextLabel")
		className.Name = "ClassName"
		className.Position = UDim2.new(1, -132, 0, 5)
		className.Size = UDim2.new(0, 58, 0, 20)
		className.BackgroundTransparency = 1
		className.Text = asset.className
		className.TextXAlignment = Enum.TextXAlignment.Right
		className.TextColor3 = Color3.fromRGB(85, 85, 85)
		className.TextSize = SECONDARY_TEXT_SIZE
		className.Font = Enum.Font.SourceSans
		className.TextTruncate = Enum.TextTruncate.AtEnd
		className.Parent = row

		local badge = Instance.new("TextLabel")
		badge.Name = "StatusBadge"
		badge.Position = UDim2.new(1, -66, 0, 7)
		badge.Size = UDim2.new(0, 56, 0, 16)
		badge.BackgroundColor3 = statusColor(asset.status)
		badge.BorderSizePixel = 0
		badge.Text = statusBadgeText(asset.status)
		badge.TextColor3 = Color3.fromRGB(255, 255, 255)
		badge.TextSize = BADGE_TEXT_SIZE
		badge.Font = Enum.Font.SourceSansBold
		badge.Parent = row

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 8)
		badgeCorner.Parent = badge

		local path = Instance.new("TextLabel")
		path.Name = "Path"
		path.Position = UDim2.new(0, 60 + indent, 0, 25)
		path.Size = UDim2.new(1, -70 - indent, 0, 18)
		path.BackgroundTransparency = 1
		path.Text = secondaryText(asset)
		path.TextXAlignment = Enum.TextXAlignment.Left
		path.TextColor3 = Color3.fromRGB(95, 95, 95)
		path.TextSize = SECONDARY_TEXT_SIZE
		path.Font = Enum.Font.SourceSans
		path.TextTruncate = Enum.TextTruncate.AtEnd
		path.Parent = row

	end

	local function sortAssets(assets: {AssetDefinition.AssetDefinition}): {AssetDefinition.AssetDefinition}
		local sorted = table.clone(assets)
		table.sort(sorted, function(left, right)
			return displayPath(left) < displayPath(right)
		end)
		return sorted
	end

	local function newNode(name: string, path: string): TreeNode
		return {
			name = name,
			path = path,
			children = {},
			childNames = {},
			assets = {},
		}
	end

	local function addChild(parent: TreeNode, name: string, path: string): TreeNode
		local existing = parent.children[name]
		if existing then
			return existing
		end

		local child = newNode(name, path)
		parent.children[name] = child
		table.insert(parent.childNames, name)
		table.sort(parent.childNames)
		return child
	end

	local function buildTree(assets: {AssetDefinition.AssetDefinition}): TreeNode
		local tree = newNode("root", "")
		for _, asset in sortAssets(assets) do
			local parts = splitPath(displayPath(asset))
			local node = tree
			for index = 1, math.max(#parts - 1, 0) do
				local parentPath = node.path
				local childPath = if parentPath == "" then parts[index] else parentPath .. "/" .. parts[index]
				node = addChild(node, parts[index], childPath)
			end
			table.insert(node.assets, asset)
		end
		return tree
	end

	local function nodeStatus(node: TreeNode): AssetDefinition.AssetStatus
		local best: AssetDefinition.AssetStatus = "Ready"
		for _, asset in node.assets do
			if statusRank(asset.status) > statusRank(best) then
				best = asset.status
			end
		end
		for _, childName in node.childNames do
			local childStatus = nodeStatus(node.children[childName])
			if statusRank(childStatus) > statusRank(best) then
				best = childStatus
			end
		end
		return best
	end

	local renderImpl: (() -> ())? = nil

	local function renderNode(node: TreeNode, depth: number, order: number): number
		if node.path ~= "" then
			order += 1
			local assetsInNode = {}
			collectNodeAssets(node, assetsInNode)
			addFolderRow(node.name, node.path, order, depth, nodeStatus(node), assetsInNode, function()
				if renderImpl then
					renderImpl()
				end
			end)
			if collapsed[node.path] then
				return order
			end
			depth += 1
		end

		for _, childName in node.childNames do
			order = renderNode(node.children[childName], depth, order)
		end

		for _, asset in node.assets do
			order += 1
			addRow(asset, order, depth, function()
				if renderImpl then
					renderImpl()
				end
			end)
		end

		return order
	end

	return {
		root = root,
		render = function(assets: {AssetDefinition.AssetDefinition})
			currentAssets = assets
			if not renderImpl then
				renderImpl = function()
					clear()
					if #currentAssets == 0 then
						addEmpty(emptyMessage or "No assets to show.")
						return
					end
					renderNode(buildTree(currentAssets), 0, 0)
				end
			end

			clear()
			if #assets == 0 then
				addEmpty(emptyMessage or "No assets to show.")
				return
			end
			renderNode(buildTree(assets), 0, 0)
		end,
	}
end

return AssetList
