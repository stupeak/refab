--!strict

local Settings = {
	PluginName = "Refab",
	ToolbarName = "Refab",
	ButtonText = "Refab",
	ButtonTooltip = "Open Refab asset packaging tools",
	WidgetId = "Refab_MainWindow",
	AssetsRootFolder = "assets",
	Attributes = {
		AssetId = "RefabAssetId",
		SourcePath = "RefabSourcePath",
		TargetPath = "RefabTargetPath",
		Version = "RefabVersion",
	},
	SupportedRoots = {
		"Workspace",
		"StarterGui",
		"ReplicatedStorage",
	},
}

return Settings
