--!strict

local Button = require(script.Parent.components.Button)
local AssetList = require(script.Parent.components.AssetList)
local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)

local ImportView = {}

export type Handle = {
	root: Frame,
	refresh: () -> (),
	reset: () -> (),
}

local function createToolbarButton(text: string): TextButton
	local button = Button.create({ text = text, height = 26 })
	button.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	button.BorderColor3 = Color3.fromRGB(180, 180, 180)
	button.TextColor3 = Color3.fromRGB(45, 45, 45)
	button.TextSize = 14
	return button
end

local function countAssets(assets: {AssetDefinition.AssetDefinition}): (number, number)
	local newCount = 0
	local changedCount = 0
	for _, asset in assets do
		if asset.status == "New" then
			newCount += 1
		elseif asset.status == "Changed" then
			changedCount += 1
		end
	end
	return newCount, changedCount
end

function ImportView.create(importService: any, setStatus: (string, boolean?) -> (), onCountsChanged: ((number, number) -> ())?): Handle
	local assets: {AssetDefinition.AssetDefinition} = {}

	local root = Instance.new("Frame")
	root.Name = "ImportView"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1

	local panel = Instance.new("Frame")
	panel.Name = "AssetPanel"
	panel.Size = UDim2.new(1, 0, 1, -54)
	panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	panel.BorderColor3 = Color3.fromRGB(205, 205, 205)
	panel.BorderSizePixel = 1
	panel.Parent = root

	local list = AssetList.create("No local changes to apply.")
	list.root.Position = UDim2.new(0, 0, 0, 42)
	list.root.Size = UDim2.new(1, 0, 1, -42)
	list.root.Parent = panel

	local row = Instance.new("Frame")
	row.Name = "BulkActions"
	row.Position = UDim2.new(0, 8, 0, 8)
	row.Size = UDim2.new(1, -16, 0, 28)
	row.BackgroundTransparency = 1
	row.Parent = panel

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local refreshHelperButton = createToolbarButton("Refresh")
	refreshHelperButton.Size = UDim2.new(0.5, -4, 0, 26)
	refreshHelperButton.Parent = row

	local selectAllButton = createToolbarButton("All")
	selectAllButton.Size = UDim2.new(0.25, -4, 0, 26)
	selectAllButton.Parent = row

	local deselectAllButton = createToolbarButton("None")
	deselectAllButton.Size = UDim2.new(0.25, -4, 0, 26)
	deselectAllButton.Parent = row

	local importButton = Button.create({ text = "Apply", height = 42, accent = true })
	importButton.AnchorPoint = Vector2.new(0, 1)
	importButton.Position = UDim2.new(0, 0, 1, 0)
	importButton.Parent = root

	local modal = Instance.new("Frame")
	modal.Name = "ConfirmChangedModal"
	modal.Size = UDim2.fromScale(1, 1)
	modal.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	modal.BackgroundTransparency = 0.18
	modal.Visible = false
	modal.ZIndex = 20
	modal.Parent = root

	local dialog = Instance.new("Frame")
	dialog.Name = "Dialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.new(1, -48, 0, 164)
	dialog.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dialog.BorderColor3 = Color3.fromRGB(205, 205, 205)
	dialog.BorderSizePixel = 1
	dialog.ZIndex = 21
	dialog.Parent = modal

	local dialogPadding = Instance.new("UIPadding")
	dialogPadding.PaddingTop = UDim.new(0, 12)
	dialogPadding.PaddingBottom = UDim.new(0, 12)
	dialogPadding.PaddingLeft = UDim.new(0, 12)
	dialogPadding.PaddingRight = UDim.new(0, 12)
	dialogPadding.Parent = dialog

	local dialogTitle = Instance.new("TextLabel")
	dialogTitle.Name = "Title"
	dialogTitle.Size = UDim2.new(1, 0, 0, 24)
	dialogTitle.BackgroundTransparency = 1
	dialogTitle.Text = "Changed assets staged"
	dialogTitle.TextXAlignment = Enum.TextXAlignment.Left
	dialogTitle.TextColor3 = Color3.fromRGB(170, 120, 0)
	dialogTitle.TextSize = 18
	dialogTitle.Font = Enum.Font.SourceSansBold
	dialogTitle.ZIndex = 22
	dialogTitle.Parent = dialog

	local dialogBody = Instance.new("TextLabel")
	dialogBody.Name = "Body"
	dialogBody.Position = UDim2.new(0, 0, 0, 32)
	dialogBody.Size = UDim2.new(1, 0, 0, 68)
	dialogBody.BackgroundTransparency = 1
	dialogBody.Text = ""
	dialogBody.TextXAlignment = Enum.TextXAlignment.Left
	dialogBody.TextYAlignment = Enum.TextYAlignment.Top
	dialogBody.TextWrapped = true
	dialogBody.TextColor3 = Color3.fromRGB(55, 55, 55)
	dialogBody.TextSize = 14
	dialogBody.Font = Enum.Font.SourceSans
	dialogBody.ZIndex = 22
	dialogBody.Parent = dialog

	local cancelButton = Button.create({ text = "Cancel", height = 32 })
	cancelButton.Position = UDim2.new(1, -204, 1, -32)
	cancelButton.Size = UDim2.new(0, 96, 0, 32)
	cancelButton.ZIndex = 22
	cancelButton.Parent = dialog

	local applyAnywayButton = Button.create({ text = "Apply Anyway", height = 32, accent = true })
	applyAnywayButton.Position = UDim2.new(1, -100, 1, -32)
	applyAnywayButton.Size = UDim2.new(0, 100, 0, 32)
	applyAnywayButton.ZIndex = 22
	applyAnywayButton.Parent = dialog

	local function render()
		list.render(assets)
		if onCountsChanged then
			onCountsChanged(countAssets(assets))
		end
	end

	local function getStagedChangedAssets(): {AssetDefinition.AssetDefinition}
		local changed = {}
		for _, asset in assets do
			if asset.selected and asset.status == "Changed" then
				table.insert(changed, asset)
			end
		end
		return changed
	end

	local refreshHelper: () -> ()

	local function applySelected()
		local result = importService:importSelectedFromHelper(assets)
		setStatus(result.message, not result.ok)
		if result.ok then
			refreshHelper()
		end
	end

	local function showChangedConfirm(changedAssets: {AssetDefinition.AssetDefinition})
		local preview = {}
		for index, asset in changedAssets do
			if index > 3 then
				table.insert(preview, "and " .. tostring(#changedAssets - 3) .. " more")
				break
			end
			table.insert(preview, asset.assetPath)
		end
		dialogBody.Text = "Applying changed local assets will overwrite the matching Instances in the place with the file version.\n\n" .. table.concat(preview, "\n")
		modal.Visible = true
	end

	refreshHelper = function()
		local loadedAssets, message = importService:listHelperAssets()
		assets = loadedAssets
		if #assets == 0 then
			if message and message ~= "No local changes to apply." then
				setStatus(message, true)
			end
		end
		render()
	end

	refreshHelperButton.MouseButton1Click:Connect(refreshHelper)

	selectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			asset.selected = true
		end
		render()
	end)

	deselectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			asset.selected = false
		end
		render()
	end)

	cancelButton.MouseButton1Click:Connect(function()
		modal.Visible = false
		setStatus("Apply cancelled.")
	end)

	applyAnywayButton.MouseButton1Click:Connect(function()
		modal.Visible = false
		applySelected()
	end)

	importButton.MouseButton1Click:Connect(function()
		local changedAssets = getStagedChangedAssets()
		if #changedAssets > 0 then
			showChangedConfirm(changedAssets)
			return
		end
		applySelected()
	end)

	local function reset()
		assets = {}
		modal.Visible = false
		render()
	end

	return {
		root = root,
		refresh = refreshHelper,
		reset = reset,
	}
end

return ImportView
