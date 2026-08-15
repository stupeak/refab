--!strict

local ExportView = require(script.Parent.ExportView)
local ImportView = require(script.Parent.ImportView)
local Button = require(script.Parent.components.Button)
local Settings = require(script.Parent.Parent.config.Settings)

local MainWindow = {}
MainWindow.__index = MainWindow

export type MainWindow = typeof(setmetatable({} :: {
	_plugin: Plugin,
	_widget: DockWidgetPluginGui,
	_exportView: ExportView.Handle?,
	_importView: ImportView.Handle?,
	_content: Frame,
	_tabs: Frame,
	_statePanel: Frame,
	_stateTitle: TextLabel,
	_stateBody: TextLabel,
	_exportTab: TextButton,
	_importTab: TextButton,
	_helperState: TextLabel,
	_helperProject: TextLabel,
	_helperAssets: TextLabel,
	_connectButton: TextButton,
	_connected: boolean,
	_refreshHelper: (() -> ())?,
	_mode: "Export" | "Import",
}, MainWindow))

local function createCountBadge(name: string, color: Color3): TextLabel
	local badge = Instance.new("TextLabel")
	badge.Name = name
	badge.Size = UDim2.new(0, 18, 0, 16)
	badge.BackgroundColor3 = color
	badge.BorderSizePixel = 0
	badge.Text = "0"
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.TextSize = 11
	badge.Font = Enum.Font.SourceSansBold
	badge.Visible = false
	badge.Parent = nil
	badge.AutomaticSize = Enum.AutomaticSize.X

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	return badge
end

local function createTab(text: string): TextButton
	local tab = Button.create({ text = "", height = 28 })
	tab.Size = UDim2.new(0.5, -3, 0, 28)
	tab.BackgroundColor3 = Color3.fromRGB(222, 222, 222)
	tab.BorderColor3 = Color3.fromRGB(150, 150, 150)
	tab.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = tab

	local tabLabel = Instance.new("TextLabel")
	tabLabel.Name = "TabLabel"
	tabLabel.Position = UDim2.new(0, 10, 0, 0)
	tabLabel.Size = UDim2.new(1, -76, 1, 0)
	tabLabel.BackgroundTransparency = 1
	tabLabel.Text = text
	tabLabel.TextXAlignment = Enum.TextXAlignment.Left
	tabLabel.TextYAlignment = Enum.TextYAlignment.Center
	tabLabel.TextColor3 = Color3.fromRGB(35, 35, 35)
	tabLabel.TextSize = 14
	tabLabel.Font = Enum.Font.SourceSansSemibold
	tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
	tabLabel.Parent = tab

	local badgeGroup = Instance.new("Frame")
	badgeGroup.Name = "BadgeGroup"
	badgeGroup.AnchorPoint = Vector2.new(1, 0.5)
	badgeGroup.Position = UDim2.new(1, -8, 0.5, 0)
	badgeGroup.Size = UDim2.new(0, 0, 0, 16)
	badgeGroup.AutomaticSize = Enum.AutomaticSize.X
	badgeGroup.BackgroundTransparency = 1
	badgeGroup.Parent = tab

	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgeLayout.Padding = UDim.new(0, 4)
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.Parent = badgeGroup

	local newBadge = createCountBadge("NewCountBadge", Color3.fromRGB(36, 132, 82))
	newBadge.LayoutOrder = 1
	newBadge.Parent = badgeGroup

	local changedBadge = createCountBadge("ChangedCountBadge", Color3.fromRGB(180, 128, 24))
	changedBadge.LayoutOrder = 2
	changedBadge.Parent = badgeGroup

	return tab
end

local function setTabCounts(tab: TextButton, newCount: number, changedCount: number)
	local badgeGroup = tab:FindFirstChild("BadgeGroup")
	local newBadge = if badgeGroup then badgeGroup:FindFirstChild("NewCountBadge") else nil
	if newBadge and newBadge:IsA("TextLabel") then
		newBadge.Text = tostring(newCount)
		newBadge.Visible = newCount > 0
	end

	local changedBadge = if badgeGroup then badgeGroup:FindFirstChild("ChangedCountBadge") else nil
	if changedBadge and changedBadge:IsA("TextLabel") then
		changedBadge.Text = tostring(changedCount)
		changedBadge.Visible = changedCount > 0
	end

	local visibleBadgeCount = 0
	if newCount > 0 then
		visibleBadgeCount += 1
	end
	if changedCount > 0 then
		visibleBadgeCount += 1
	end

	local digitCount = math.max(#tostring(newCount), #tostring(changedCount))
	local estimatedBadgeWidth = if visibleBadgeCount == 0 then 0 else math.max(18, 12 + digitCount * 7)
	local reservedWidth = visibleBadgeCount * estimatedBadgeWidth + math.max(visibleBadgeCount - 1, 0) * 4 + 20
	local label = tab:FindFirstChild("TabLabel")
	if label and label:IsA("TextLabel") then
		label.Size = UDim2.new(1, -math.max(40, reservedWidth), 1, 0)
	end
end

local function setTabSelected(tab: TextButton, selected: boolean)
	tab.BackgroundColor3 = if selected then Color3.fromRGB(40, 105, 170) else Color3.fromRGB(232, 232, 232)
	tab.BorderColor3 = if selected then Color3.fromRGB(28, 82, 138) else Color3.fromRGB(178, 178, 178)
	tab.BorderSizePixel = if selected then 2 else 1
	tab.Font = if selected then Enum.Font.SourceSansBold else Enum.Font.SourceSansSemibold
	local label = tab:FindFirstChild("TabLabel")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = if selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(35, 35, 35)
		label.Font = if selected then Enum.Font.SourceSansBold else Enum.Font.SourceSansSemibold
	end

end

local function createLabel(text: string, size: number?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = Color3.fromRGB(65, 65, 65)
	label.TextSize = size or 13
	label.Font = if bold then Enum.Font.SourceSansSemibold else Enum.Font.SourceSans
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function formatConnectIssue(rawMessage: string?): string
	local details = tostring(rawMessage or "")
	local lowerDetails = string.lower(details)

	local reason = "Refab could not connect to the local CLI."
	local action = "Run `refab run` from your Roblox project root, then click Connect again."

	if string.find(lowerDetails, "http requests") or string.find(lowerDetails, "httprequests") then
		reason = "Roblox Studio is blocking local HTTP requests."
		action = "Enable HTTP Requests in Game Settings, then try Connect again."
	elseif string.find(lowerDetails, "invalid refab cli json")
		or string.find(lowerDetails, "can't parse json")
		or string.find(lowerDetails, "cannot parse json")
		or string.find(lowerDetails, "http 404")
		or string.find(lowerDetails, "http 405")
		or string.find(lowerDetails, "http 500")
	then
		reason = "Something else may be running on Refab's local port."
		action = "Stop the process using port 34874, then start Refab with `refab run`."
	elseif string.find(lowerDetails, "connection")
		or string.find(lowerDetails, "connect")
		or string.find(lowerDetails, "refused")
		or string.find(lowerDetails, "timed")
		or string.find(lowerDetails, "failed")
		or string.find(lowerDetails, "not running")
	then
		reason = "Refab CLI does not look like it is running."
	end

	if details == "" then
		return reason .. "\n" .. action
	end

	return reason .. "\n" .. action .. "\n\nDetails: " .. details
end

function MainWindow.new(plugin: Plugin, exportService: any, importService: any, _projectSettings: any, helperClient: any): MainWindow
	local savedOpen = plugin:GetSetting(Settings.WindowOpenSetting) == true
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		savedOpen,
		false,
		420,
		640,
		340,
		500
	)

	local widget = plugin:CreateDockWidgetPluginGuiAsync(Settings.WidgetId, widgetInfo)
	local titleText = Settings.PluginName .. " v" .. Settings.PluginVersion
	widget.Title = titleText
	widget.Name = Settings.WidgetId

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	root.BorderSizePixel = 0
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = root

	local helperFrame = Instance.new("Frame")
	helperFrame.Name = "HelperPanel"
	helperFrame.Position = UDim2.new(0, 0, 0, 0)
	helperFrame.Size = UDim2.new(1, 0, 0, 58)
	helperFrame.BackgroundColor3 = Color3.fromRGB(238, 238, 238)
	helperFrame.BorderColor3 = Color3.fromRGB(205, 205, 205)
	helperFrame.BorderSizePixel = 1
	helperFrame.Parent = root
	addCorner(helperFrame, 10)

	local helperPadding = Instance.new("UIPadding")
	helperPadding.PaddingTop = UDim.new(0, 6)
	helperPadding.PaddingBottom = UDim.new(0, 6)
	helperPadding.PaddingLeft = UDim.new(0, 8)
	helperPadding.PaddingRight = UDim.new(0, 8)
	helperPadding.Parent = helperFrame

	local helperState = createLabel("", 13, true)
	helperState.Position = UDim2.new(0, 0, 0, 0)
	helperState.Size = UDim2.new(1, -112, 0, 20)
	helperState.TextColor3 = Color3.fromRGB(90, 90, 90)
	helperState.Parent = helperFrame

	local connectButton = Button.create({ text = "Connect", height = 28, accent = true })
	connectButton.Position = UDim2.new(1, -104, 0, 0)
	connectButton.Size = UDim2.new(0, 104, 0, 28)
	connectButton.Parent = helperFrame

	local helperProject = createLabel("Project: -", 13, false)
	helperProject.Position = UDim2.new(0, 0, 0, 20)
	helperProject.Size = UDim2.new(1, -112, 0, 18)
	helperProject.Parent = helperFrame

	local helperAssets = createLabel("Assets: -", 13, false)
	helperAssets.Position = UDim2.new(1, -104, 0, 34)
	helperAssets.Size = UDim2.new(1, 0, 0, 18)
	helperAssets.TextXAlignment = Enum.TextXAlignment.Right
	helperAssets.Parent = helperFrame

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.new(0, 0, 0, 66)
	tabs.Size = UDim2.new(1, 0, 0, 28)
	tabs.BackgroundTransparency = 1
	tabs.Visible = false
	tabs.Parent = root

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local importTab = createTab("To Roblox")
	importTab.Parent = tabs

	local exportTab = createTab("To Local")
	exportTab.Parent = tabs

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 0, 0, 104)
	content.Size = UDim2.new(1, 0, 1, -104)
	content.BackgroundTransparency = 1
	content.Visible = false
	content.Parent = root

	local statePanel = Instance.new("Frame")
	statePanel.Name = "StatePanel"
	statePanel.Position = UDim2.new(0, 0, 0, 104)
	statePanel.Size = UDim2.new(1, 0, 1, -104)
	statePanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	statePanel.BorderColor3 = Color3.fromRGB(205, 205, 205)
	statePanel.BorderSizePixel = 1
	statePanel.Visible = false
	statePanel.Parent = root
	addCorner(statePanel, 10)

	local stateTitle = Instance.new("TextLabel")
	stateTitle.Name = "Title"
	stateTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	stateTitle.Position = UDim2.new(0.5, 0, 0.5, -22)
	stateTitle.Size = UDim2.new(1, -40, 0, 28)
	stateTitle.BackgroundTransparency = 1
	stateTitle.Text = ""
	stateTitle.TextColor3 = Color3.fromRGB(45, 45, 45)
	stateTitle.TextSize = 20
	stateTitle.Font = Enum.Font.SourceSansSemibold
	stateTitle.TextXAlignment = Enum.TextXAlignment.Center
	stateTitle.TextTruncate = Enum.TextTruncate.AtEnd
	stateTitle.Parent = statePanel

	local stateBody = Instance.new("TextLabel")
	stateBody.Name = "Body"
	stateBody.AnchorPoint = Vector2.new(0.5, 0.5)
	stateBody.Position = UDim2.new(0.5, 0, 0.5, 18)
	stateBody.Size = UDim2.new(1, -48, 0, 60)
	stateBody.BackgroundTransparency = 1
	stateBody.Text = ""
	stateBody.TextColor3 = Color3.fromRGB(90, 90, 90)
	stateBody.TextSize = 14
	stateBody.Font = Enum.Font.SourceSans
	stateBody.TextWrapped = true
	stateBody.TextXAlignment = Enum.TextXAlignment.Center
	stateBody.TextYAlignment = Enum.TextYAlignment.Top
	stateBody.Parent = statePanel

	local self = setmetatable({
		_plugin = plugin,
		_widget = widget,
		_exportView = nil,
		_importView = nil,
		_content = content,
		_tabs = tabs,
		_statePanel = statePanel,
		_stateTitle = stateTitle,
		_stateBody = stateBody,
		_exportTab = exportTab,
		_importTab = importTab,
		_helperState = helperState,
		_helperProject = helperProject,
		_helperAssets = helperAssets,
		_connectButton = connectButton,
		_connected = false,
		_refreshHelper = nil,
		_mode = "Import",
	}, MainWindow)

	local function showMainUi()
		tabs.Visible = true
		content.Visible = true
		statePanel.Visible = false
	end

	local function showEmptyState(title: string?, body: string?, issue: boolean?)
		tabs.Visible = false
		content.Visible = false
		if not title or title == "" then
			statePanel.Visible = false
			return
		end
		statePanel.Visible = true
		stateTitle.Text = title
		stateTitle.TextColor3 = if issue then Color3.fromRGB(150, 74, 28) else Color3.fromRGB(45, 45, 45)
		stateBody.Text = body or ""
	end

	local function setStatus(message: string, isError: boolean?)
		if isError then
			showEmptyState("Needs attention", message, true)
		end
	end

	local function refreshHelper(showStatus: boolean?)
		if showStatus then
			self._connected = false
			showEmptyState("Connecting...", "Checking Refab CLI at " .. Settings.HelperBaseUrl, false)
			connectButton.Text = "Connecting..."
		end

		local helperStatus = helperClient:getStatus()
		if helperStatus.ok then
			self._connected = true
			showMainUi()
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(20, 130, 70)
			helperProject.Text = "Project: " .. tostring(helperStatus.projectRoot or "-")
			helperAssets.Text = "Assets: " .. tostring(helperStatus.assetCount or 0)
			connectButton.Text = "Disconnect"
			connectButton.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
			connectButton.BorderColor3 = Color3.fromRGB(150, 150, 150)
			connectButton.TextColor3 = Color3.fromRGB(35, 35, 35)
			self:setMode(self._mode)
		else
			self._connected = false
			if showStatus then
				showEmptyState("Could not connect", formatConnectIssue(helperStatus.message), true)
			else
				showEmptyState(nil, nil, false)
			end
			setTabCounts(importTab, 0, 0)
			setTabCounts(exportTab, 0, 0)
			if self._importView then
				self._importView.reset()
			end
			if self._exportView then
				self._exportView.reset()
			end
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(150, 74, 28)
			helperProject.Text = "Project: -"
			helperAssets.Text = "Offline"
			connectButton.Text = "Connect"
			connectButton.BackgroundColor3 = Color3.fromRGB(40, 105, 170)
			connectButton.BorderColor3 = Color3.fromRGB(28, 82, 138)
			connectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	self._refreshHelper = refreshHelper
	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		plugin:SetSetting(Settings.WindowOpenSetting, widget.Enabled)
		if widget.Enabled then
			refreshHelper(false)
		end
	end)

	connectButton.MouseButton1Click:Connect(function()
		if self._connected then
			self._connected = false
			showEmptyState(nil, nil, false)
			setTabCounts(importTab, 0, 0)
			setTabCounts(exportTab, 0, 0)
			if self._importView then
				self._importView.reset()
			end
			if self._exportView then
				self._exportView.reset()
			end
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(90, 90, 90)
			helperProject.Text = "Project: -"
			helperAssets.Text = "Disconnected"
			connectButton.Text = "Connect"
			connectButton.BackgroundColor3 = Color3.fromRGB(40, 105, 170)
			connectButton.BorderColor3 = Color3.fromRGB(28, 82, 138)
			connectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			return
		end

		refreshHelper(true)
	end)

	self._exportView = ExportView.create(exportService, setStatus, function(newCount: number, changedCount: number)
		setTabCounts(exportTab, newCount, changedCount)
	end)
	self._exportView.root.Parent = content

	self._importView = ImportView.create(importService, setStatus, function(newCount: number, changedCount: number)
		setTabCounts(importTab, newCount, changedCount)
	end)
	self._importView.root.Parent = content

	exportTab.MouseButton1Click:Connect(function()
		self:setMode("Export")
	end)

	importTab.MouseButton1Click:Connect(function()
		self:setMode("Import")
	end)

	refreshHelper(false)
	self:setMode("Import")
	return self
end

function MainWindow:setMode(mode: "Export" | "Import")
	self._mode = mode
	local showingExport = mode == "Export"
	if self._exportView then
		self._exportView.root.Visible = showingExport
		if self._connected and showingExport then
			self._exportView.refresh()
		end
	end
	if self._importView then
		self._importView.root.Visible = not showingExport
		if self._connected and not showingExport then
			self._importView.refresh()
		end
	end

	setTabSelected(self._exportTab, showingExport)
	setTabSelected(self._importTab, not showingExport)
end

function MainWindow:setEnabled(enabled: boolean)
	self._widget.Enabled = enabled
	self._plugin:SetSetting(Settings.WindowOpenSetting, enabled)
	if enabled and self._refreshHelper then
		self._refreshHelper(false)
	end
end

function MainWindow:isEnabled(): boolean
	return self._widget.Enabled
end

return MainWindow
