--!strict

local Settings = require(script.Parent.Parent.config.Settings)

local AssetPathResolver = {}

local rootLookup: {[string]: boolean} = {}
for _, rootName in Settings.SupportedRoots do
	rootLookup[rootName] = true
end

local function sanitizeSegment(segment: string): string
	local cleaned = segment:gsub("[\\/:*?\"<>|]", "_")
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
	if cleaned == "" then
		return "Unnamed"
	end
	return cleaned
end

local function stripExtension(name: string): string
	return (name:gsub("%.rbxm$", ""):gsub("%.rbxmx$", ""))
end

function AssetPathResolver.getSupportedRoot(instance: Instance): Instance?
	local current: Instance? = instance
	while current and current ~= game do
		if rootLookup[current.Name] and current.Parent == game then
			return current
		end
		current = current.Parent
	end
	return nil
end

function AssetPathResolver.instanceToAssetPath(instance: Instance): (boolean, string?, string?)
	local root = AssetPathResolver.getSupportedRoot(instance)
	if not root then
		return false, nil, "This asset is outside a supported root."
	end

	local segments = {}
	local current: Instance? = instance
	while current and current ~= root.Parent do
		table.insert(segments, 1, sanitizeSegment(current.Name))
		current = current.Parent
	end

	local fileName = table.remove(segments)
	if not fileName then
		return false, nil, "Unable to resolve this asset path."
	end

	local parentPath = table.concat(segments, "/")
	local assetPath = parentPath .. "/" .. fileName .. ".rbxm"
	return true, assetPath, parentPath
end

function AssetPathResolver.fileNameToAssetPath(fileName: string): string
	local normalized = fileName:gsub("\\", "/")
	normalized = normalized:gsub("^/+", "")
	if not normalized:match("%.rbxm$") and not normalized:match("%.rbxmx$") then
		normalized ..= ".rbxm"
	end

	if not normalized:match("^" .. Settings.AssetsRootFolder .. "/") then
		local guessedRoot = normalized:match("^([^/]+)/")
		if guessedRoot and rootLookup[guessedRoot] then
			normalized = Settings.AssetsRootFolder .. "/" .. normalized
		end
	end

	return normalized
end

function AssetPathResolver.assetPathToParent(assetPath: string): (boolean, Instance?, string?)
	local normalized = assetPath:gsub("\\", "/")
	normalized = normalized:gsub("^" .. Settings.AssetsRootFolder .. "/", "")

	local parts = {}
	for part in normalized:gmatch("[^/]+") do
		table.insert(parts, part)
	end

	if #parts < 2 then
		return false, nil, "Asset path must include a supported root and file name."
	end

	local rootName = parts[1]
	if not rootLookup[rootName] then
		return false, nil, "Unsupported asset root: " .. rootName
	end

	local parent: Instance? = game:FindFirstChild(rootName)
	if not parent then
		return false, nil, "Roblox service not found: " .. rootName
	end

	for index = 2, #parts - 1 do
		local folderName = stripExtension(parts[index])
		local child = parent:FindFirstChild(folderName)
		if not child then
			child = Instance.new("Folder")
			child.Name = folderName
			child.Parent = parent
		end
		parent = child
	end

	return true, parent, nil
end

function AssetPathResolver.fileNameToParentPath(fileName: string): string
	local assetPath = AssetPathResolver.fileNameToAssetPath(fileName)
	local normalized = assetPath:gsub("^" .. Settings.AssetsRootFolder .. "/", "")
	local fileOnly = normalized:match("([^/]+)$") or normalized
	if fileOnly == normalized then
		return ""
	end
	return normalized:sub(1, #normalized - #fileOnly - 1)
end

return AssetPathResolver
