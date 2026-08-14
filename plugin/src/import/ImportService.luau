--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SerializationService = game:GetService("SerializationService")

local AssetPathResolver = require(script.Parent.Parent.core.AssetPathResolver)
local AssetRegistry = require(script.Parent.Parent.core.AssetRegistry)
local Base64 = require(script.Parent.Parent.core.Base64)
local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)
local Settings = require(script.Parent.Parent.config.Settings)

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

local function stripExtension(name: string): string
	return (name:gsub("%.rbxm$", ""):gsub("%.rbxmx$", ""))
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

local function compareLocalAssetToRoblox(helperClient: any, source: string, existingTarget: Instance?): (AssetDefinition.AssetStatus, string?)
	if not existingTarget then
		return "New", nil
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

		if not hasSupportedRoot(source) then
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
				message = "Unsupported asset root. Put the file under assets/Workspace, assets/StarterGui, or assets/ReplicatedStorage.",
				sourceFile = nil,
			})
			continue
		end

		local existingTarget = findExistingTarget(source)
		local status, compareMessage = compareLocalAssetToRoblox(self._helperClient, source, existingTarget)
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

	local recording = ChangeHistoryService:TryBeginRecording("Refab Import", "Import Refab helper assets")
	local imported = 0

	for _, asset in selectedAssets do
		local readOk, dataBase64, helperAsset, readMessage = self._helperClient:readAsset(asset.assetPath)
		if not readOk or not dataBase64 then
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			return {
				ok = false,
				message = readMessage or ("Failed to read " .. asset.assetPath .. " from helper."),
				count = imported,
			}
		end

		local binary = Base64.decode(dataBase64)
		local serialized = buffer.fromstring(binary)
		local deserializeOk, deserializedOrError = pcall(function()
			return SerializationService:DeserializeInstancesAsync(serialized)
		end)

		if not deserializeOk or typeof(deserializedOrError) ~= "table" then
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			return {
				ok = false,
				message = "Failed to deserialize " .. asset.assetPath .. ": " .. tostring(deserializedOrError),
				count = imported,
			}
		end

		local okParent, parent, parentMessage = AssetPathResolver.assetPathToParent(asset.assetPath)
		if not okParent or not parent then
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			return {
				ok = false,
				message = parentMessage or ("Failed to resolve parent for " .. asset.assetPath),
				count = imported,
			}
		end

		local deserialized = deserializedOrError :: {Instance}
		for _, instance in deserialized do
			local existing = parent:FindFirstChild(instance.Name)
			if existing then
				existing:Destroy()
			end
			instance.Parent = parent
			if helperAsset and helperAsset.id then
				local targetPath = helperAsset.target or ""
				AssetRegistry.register(instance, asset.assetPath, targetPath)
			end
			imported += 1
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	return {
		ok = true,
		message = "Applied " .. tostring(imported) .. " local asset instance(s) to the place.",
		count = imported,
	}
end

return ImportService
