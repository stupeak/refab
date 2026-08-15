--!strict

local Settings = require(script.Parent.Parent.config.Settings)

local AssetScope = {}

export type AssetTypeDefinition = {
	id: string,
	label: string,
	canExport: boolean,
	canImport: boolean,
	gitVersioned: boolean,
	destination: string,
	dependencies: {string},
	classes: {string},
}

local rootLookup: {[string]: boolean} = {}
for _, rootName in Settings.SupportedRoots do
	rootLookup[rootName] = true
end

function AssetScope.isSupportedRootName(rootName: string): boolean
	return rootLookup[rootName] == true
end

function AssetScope.getSupportedRootNames(): {string}
	return table.clone(Settings.SupportedRoots)
end

function AssetScope.formatSupportedRoots(): string
	return table.concat(Settings.SupportedRoots, ", ")
end

function AssetScope.isAssetPathInSupportedRoot(assetPath: string): boolean
	local normalized = assetPath:gsub("\\", "/")
	normalized = normalized:gsub("^" .. Settings.AssetsRootFolder .. "/", "")
	local rootName = normalized:match("^([^/]+)/")
	return rootName ~= nil and AssetScope.isSupportedRootName(rootName)
end

function AssetScope.getAssetTypes(): {AssetTypeDefinition}
	return table.clone(Settings.AssetTypes)
end

return AssetScope
