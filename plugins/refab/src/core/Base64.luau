--!strict

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Base64 = {}

function Base64.encode(input: string): string
	local output = {}
	local length = #input
	local index = 1

	while index <= length do
		local byte1 = string.byte(input, index) or 0
		local byte2 = string.byte(input, index + 1) or 0
		local byte3 = string.byte(input, index + 2) or 0

		local combined = bit32.lshift(byte1, 16) + bit32.lshift(byte2, 8) + byte3
		local char1 = bit32.band(bit32.rshift(combined, 18), 63)
		local char2 = bit32.band(bit32.rshift(combined, 12), 63)
		local char3 = bit32.band(bit32.rshift(combined, 6), 63)
		local char4 = bit32.band(combined, 63)

		table.insert(output, alphabet:sub(char1 + 1, char1 + 1))
		table.insert(output, alphabet:sub(char2 + 1, char2 + 1))

		if index + 1 <= length then
			table.insert(output, alphabet:sub(char3 + 1, char3 + 1))
		else
			table.insert(output, "=")
		end

		if index + 2 <= length then
			table.insert(output, alphabet:sub(char4 + 1, char4 + 1))
		else
			table.insert(output, "=")
		end

		index += 3
	end

	return table.concat(output)
end

function Base64.decode(input: string): string
	local clean = input:gsub("%s", "")
	local output = {}
	local index = 1

	while index <= #clean do
		local chars = {
			clean:sub(index, index),
			clean:sub(index + 1, index + 1),
			clean:sub(index + 2, index + 2),
			clean:sub(index + 3, index + 3),
		}

		local values = {}
		for i = 1, 4 do
			if chars[i] == "=" or chars[i] == "" then
				values[i] = 0
			else
				local found = alphabet:find(chars[i], 1, true)
				values[i] = if found then found - 1 else 0
			end
		end

		local combined = bit32.lshift(values[1], 18)
			+ bit32.lshift(values[2], 12)
			+ bit32.lshift(values[3], 6)
			+ values[4]

		local byte1 = bit32.band(bit32.rshift(combined, 16), 255)
		local byte2 = bit32.band(bit32.rshift(combined, 8), 255)
		local byte3 = bit32.band(combined, 255)

		table.insert(output, string.char(byte1))
		if chars[3] ~= "=" then
			table.insert(output, string.char(byte2))
		end
		if chars[4] ~= "=" then
			table.insert(output, string.char(byte3))
		end

		index += 4
	end

	return table.concat(output)
end

return Base64
