--!strict

export type AssetStatus = "Ready" | "Warning" | "Error"

export type AssetDefinition = {
	id: string,
	name: string,
	className: string,
	instance: Instance?,
	assetPath: string,
	parentPath: string,
	selected: boolean,
	status: AssetStatus,
	message: string?,
	sourceFile: Instance?,
}

local AssetDefinition = {}

function AssetDefinition.fromInstance(instance: Instance, assetPath: string, parentPath: string): AssetDefinition
	return {
		id = instance:GetDebugId(0),
		name = instance.Name,
		className = instance.ClassName,
		instance = instance,
		assetPath = assetPath,
		parentPath = parentPath,
		selected = true,
		status = "Ready",
		message = nil,
		sourceFile = nil,
	}
end

function AssetDefinition.fromFile(file: Instance, assetPath: string, parentPath: string): AssetDefinition
	local displayName = file.Name
	if displayName == "" then
		displayName = assetPath
	end

	return {
		id = file:GetDebugId(0),
		name = displayName,
		className = file.ClassName,
		instance = nil,
		assetPath = assetPath,
		parentPath = parentPath,
		selected = true,
		status = "Ready",
		message = nil,
		sourceFile = file,
	}
end

return AssetDefinition
