--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")

local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)
local AssetPathResolver = require(script.Parent.Parent.core.AssetPathResolver)
local Settings = require(script.Parent.Parent.config.Settings)

export type ImportResult = {
	ok: boolean,
	message: string,
	count: number,
}

local ImportService = {}
ImportService.__index = ImportService

function ImportService.new()
	return setmetatable({}, ImportService)
end

local function hasSupportedRoot(assetPath: string): boolean
	local normalized = assetPath:gsub("\\", "/")
	normalized = normalized:gsub("^" .. Settings.AssetsRootFolder .. "/", "")
	local rootName = normalized:match("^([^/]+)/")
	if not rootName then
		return false
	end

	for _, supportedRoot in Settings.SupportedRoots do
		if rootName == supportedRoot then
			return true
		end
	end

	return false
end

function ImportService:promptForFiles(): {AssetDefinition.AssetDefinition}
	local importedFiles = {}
	local ok, result = pcall(function()
		return StudioService:PromptImportFilesAsync({ "rbxm", "rbxmx" })
	end)

	if not ok or not result then
		return importedFiles
	end

	for _, file in result do
		local assetPath = AssetPathResolver.fileNameToAssetPath(file.Name)
		local parentPath = AssetPathResolver.fileNameToParentPath(file.Name)
		local asset = AssetDefinition.fromFile(file, assetPath, parentPath)
		if not hasSupportedRoot(assetPath) then
			asset.status = "Error"
			asset.selected = false
			asset.message = "Native file picker exposes only the file name. Refab needs an assets/Root/... path to resolve the import target."
		end
		table.insert(importedFiles, asset)
	end

	return importedFiles
end

function ImportService:importSelected(assets: {AssetDefinition.AssetDefinition}): ImportResult
	local selectedAssets = {}
	for _, asset in assets do
		if asset.selected and asset.sourceFile then
			table.insert(selectedAssets, asset)
		end
	end

	if #selectedAssets == 0 then
		return {
			ok = false,
			message = "No import files selected.",
			count = 0,
		}
	end

	local recording = ChangeHistoryService:TryBeginRecording("Refab Import", "Import Refab assets")
	local imported = 0

	for _, asset in selectedAssets do
		local ok, parent, message = AssetPathResolver.assetPathToParent(asset.assetPath)
		if not ok or not parent then
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			return {
				ok = false,
				message = message or ("Failed to resolve parent for " .. asset.name .. "."),
				count = imported,
			}
		end

		local source = asset.sourceFile
		if source:IsA("File") then
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			return {
				ok = false,
				message = "Roblox exposes " .. asset.name .. " as a File, but does not expose a native plugin API to deserialize local .rbxm into Instances.",
				count = imported,
			}
		end

		if source.Parent ~= parent then
			source.Parent = parent
		end

		imported += 1
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	return {
		ok = true,
		message = "Imported " .. tostring(imported) .. " asset(s) into " .. Settings.AssetsRootFolder .. " mapped roots.",
		count = imported,
	}
end

return ImportService
