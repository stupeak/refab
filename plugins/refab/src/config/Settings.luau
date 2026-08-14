--!strict

local Settings = {
	PluginName = "Refab",
	PluginVersion = "1.0.1",
	ToolbarName = "Refab",
	ButtonText = "Refab",
	ButtonTooltip = "Open Refab asset packaging tools",
	WidgetId = "Refab_MainWindow",
	HelperBaseUrl = "http://127.0.0.1:34874",
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
