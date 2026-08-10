--!strict

local Settings = {
	PluginName = "Refab",
	ToolbarName = "Refab",
	ButtonText = "Refab",
	ButtonTooltip = "Open Refab asset packaging tools",
	WidgetId = "Refab_MainWindow",
	AssetsRootFolder = "assets",
	SupportedRoots = {
		"Workspace",
		"StarterGui",
		"ReplicatedStorage",
	},
	SupportedClasses = {
		Model = true,
		Folder = true,
		ScreenGui = true,
	},
}

return Settings
