--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SerializationService = game:GetService("SerializationService")

local AssetPathResolver = require(script.Parent.Parent.core.AssetPathResolver)
local AssetRegistry = require(script.Parent.Parent.core.AssetRegistry)
local Base64 = require(script.Parent.Parent.core.Base64)
local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)
local Settings = require(script.Parent.Parent.config.Settings)
local AssetScope = require(script.Parent.Parent.core.AssetScope)

export type ImportResult = {
	ok: boolean,
	message: string,
	count: number,
}

local ImportService = {}
ImportService.__index = ImportService

function ImportService.new(helperClient: any)
	return setmetatable({
		_helperClient = helperClient,
	}, ImportService)
end

local function helperStatusToAssetStatus(status: string?): AssetDefinition.AssetStatus
	if status == "new" then
		return "New"
	elseif status == "changed" then
		return "Changed"
	end
	return "Ready"
end

local function stripExtension(name: string): string
	return (name:gsub("%.[rR][bB][xX][mM]$", ""):gsub("%.[rR][bB][xX][mM][xX]$", ""))
end

local function splitAssetPath(assetPath: string): {string}
	local normalized = assetPath:gsub("\\", "/")
	normalized = normalized:gsub("^" .. Settings.AssetsRootFolder .. "/", "")
	local parts = {}
	for part in normalized:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

local function findExistingTarget(assetPath: string): Instance?
	local parts = splitAssetPath(assetPath)
	if #parts < 2 then
		return nil
	end

	local current: Instance? = game:FindFirstChild(parts[1])
	if not current then
		return nil
	end

	for index = 2, #parts - 1 do
		current = current:FindFirstChild(stripExtension(parts[index]))
		if not current then
			return nil
		end
	end

	return current:FindFirstChild(stripExtension(parts[#parts]))
end

local function beginRecording(): any?
	local ok, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording("Refab Apply", "Apply Refab assets")
	end)
	if ok then
		return recording
	end
	return nil
end

local function finishRecording(recording: any?, operation: Enum.FinishRecordingOperation)
	if not recording then
		return
	end

	pcall(function()
		ChangeHistoryService:FinishRecording(recording, operation)
	end)
end

local function fail(recording: any?, message: string, imported: number): ImportResult
	finishRecording(recording, Enum.FinishRecordingOperation.Cancel)
	return {
		ok = false,
		message = message,
		count = imported,
	}
end

local function appendFailure(failures: {string}, assetPath: string, message: string)
	table.insert(failures, assetPath .. ": " .. message)
end

local function summarizeFailures(failures: {string}, imported: number): string
	local preview = {}
	for index, message in failures do
		if index > 3 then
			table.insert(preview, "and " .. tostring(#failures - 3) .. " more")
			break
		end
		table.insert(preview, message)
	end

	local prefix = if imported > 0
		then "Applied " .. tostring(imported) .. " asset(s), but some assets could not be applied."
		else "No assets were applied."

	return prefix .. "\n\n" .. table.concat(preview, "\n")
end

local function compareLocalAssetToRoblox(helperClient: any, source: string, localHash: string?, existingTarget: Instance?): (AssetDefinition.AssetStatus, string?)
	if not existingTarget then
		return "New", nil
	end

	if AssetRegistry.hasAppliedLocalHash(existingTarget, source, localHash) then
		return "Ready", "sha256 " .. string.sub(localHash :: string, 1, 12)
	end

	local serializeOk, serializedOrError = pcall(function()
		return SerializationService:SerializeInstancesAsync({ existingTarget })
	end)
	if not serializeOk or typeof(serializedOrError) ~= "buffer" then
		return "Warning", "Unable to compare existing Roblox instance."
	end

	local compare = helperClient:compareAsset({
		source = source,
		dataBase64 = Base64.encode(buffer.tostring(serializedOrError :: buffer)),
	})
	if not compare.ok then
		return "Warning", compare.message or "Unable to compare with local library."
	end

	local status = helperStatusToAssetStatus(compare.status)
	if status == "Ready" then
		return "Ready", if compare.hash then "sha256 " .. string.sub(compare.hash, 1, 12) else nil
	end

	return status, if compare.hash then "sha256 " .. string.sub(compare.hash, 1, 12) else nil
end

function ImportService:listHelperAssets(): ({AssetDefinition.AssetDefinition}, string?)
	local ok, helperAssets, message = self._helperClient:listAssets()
	if not ok then
		return {}, message
	end

	local assets = {}
	for _, helperAsset in helperAssets do
		local source = helperAsset.source
		local parentPath = AssetPathResolver.fileNameToParentPath(source)

		if not AssetScope.isAssetPathInSupportedRoot(source) then
			table.insert(assets, {
				id = source,
				name = helperAsset.name,
				className = helperAsset.className or "rbxm",
				instance = nil,
				assetPath = source,
				fullAssetPath = source,
				parentPath = parentPath,
				assetId = source,
				managed = false,
				selected = false,
				status = "Error",
				message = "Unsupported asset root. Put the file under one of: " .. AssetScope.formatSupportedRoots() .. ".",
				sourceFile = nil,
			})
			continue
		end

		local existingTarget = findExistingTarget(source)
		local status, compareMessage = compareLocalAssetToRoblox(self._helperClient, source, helperAsset.hash, existingTarget)
		if status == "Ready" then
			continue
		end

		local asset = {
			id = source,
			name = helperAsset.name,
			className = helperAsset.className or "rbxm",
			instance = nil,
			assetPath = source,
			fullAssetPath = source,
			parentPath = parentPath,
			assetId = source,
			managed = status ~= "New",
			selected = true,
			status = status,
			message = compareMessage or (if helperAsset.hash then "local sha256 " .. string.sub(helperAsset.hash, 1, 12) else nil),
			sourceFile = nil,
		}
		table.insert(assets, asset)
	end

	if #assets == 0 and #helperAssets > 0 then
		return assets, "No local changes to apply."
	end

	return assets, nil
end

function ImportService:importSelectedFromHelper(assets: {AssetDefinition.AssetDefinition}): ImportResult
	local selectedAssets = {}
	for _, asset in assets do
		if asset.selected and asset.status ~= "Error" then
			table.insert(selectedAssets, asset)
		end
	end

	if #selectedAssets == 0 then
		return {
			ok = false,
			message = "No library assets staged.",
			count = 0,
		}
	end

	local recording = beginRecording()
	local imported = 0
	local failures = {}

	for _, asset in selectedAssets do
		local readOk, dataBase64, helperAsset, readMessage = self._helperClient:readAsset(asset.assetPath)
		if not readOk or not dataBase64 then
			appendFailure(failures, asset.assetPath, readMessage or "Failed to read file from Refab CLI.")
			continue
		end

		local binary = Base64.decode(dataBase64)
		local serialized = buffer.fromstring(binary)
		local deserializeOk, deserializedOrError = pcall(function()
			return SerializationService:DeserializeInstancesAsync(serialized)
		end)

		if not deserializeOk or typeof(deserializedOrError) ~= "table" then
			appendFailure(failures, asset.assetPath, "Failed to deserialize: " .. tostring(deserializedOrError))
			continue
		end

		local okParent, parent, parentMessage = AssetPathResolver.assetPathToParent(asset.assetPath)
		if not okParent or not parent then
			appendFailure(failures, asset.assetPath, parentMessage or "Failed to resolve parent.")
			continue
		end

		local okName, targetName, nameMessage = AssetPathResolver.assetPathToName(asset.assetPath)
		if not okName or not targetName then
			appendFailure(failures, asset.assetPath, nameMessage or "Failed to resolve asset name.")
			continue
		end

		local deserialized = deserializedOrError :: {Instance}
		if #deserialized == 0 then
			appendFailure(failures, asset.assetPath, "No Instances were found inside this file.")
			continue
		end

		local targetInstance: Instance
		if #deserialized == 1 then
			targetInstance = deserialized[1]
			targetInstance.Name = targetName
		else
			local folder = Instance.new("Folder")
			folder.Name = targetName
			for _, instance in deserialized do
				instance.Parent = folder
			end
			targetInstance = folder
		end

		local applyOk, applyError = pcall(function()
			local existing = parent:FindFirstChild(targetName)
			if existing then
				existing:Destroy()
			end
			targetInstance.Parent = parent
			if helperAsset and helperAsset.id then
				local targetPath = helperAsset.target or ""
				AssetRegistry.register(targetInstance, asset.assetPath, targetPath, helperAsset.hash)
			end
		end)

		if not applyOk then
			appendFailure(failures, asset.assetPath, "Failed to apply: " .. tostring(applyError))
			continue
		end

		imported += 1
	end

	if imported > 0 then
		finishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		finishRecording(recording, Enum.FinishRecordingOperation.Cancel)
	end

	if #failures > 0 then
		return {
			ok = false,
			message = summarizeFailures(failures, imported),
			count = imported,
		}
	end

	return {
		ok = true,
		message = "Applied " .. tostring(imported) .. " local asset(s) to the place.",
		count = imported,
	}
end

return ImportService
