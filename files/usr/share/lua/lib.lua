local _ubus = require "ubus"
local _ubus_connection = nil

-- Generic Routines

function run_process(proc)
	local handle = io.popen(proc)
	local result = handle:read("*a")
	handle:close()
	return result
end

function check_file(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	else
		file:close()
		return true
	end
end

function write_file(path, content)
	local file = io.open(path, "wb")
	if not file then return false end
	file:write(content)
	file:close()
	return true
end

function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local content = file:read "*all"
	file:close()
	return content
end

function read_lines(path)
	if not check_file(path) then return nil end
	local file = io.lines(path)
	local content = {}
	for line in file do
		table.insert(content, line)
	end
	return content
end

function trim_file(path)
	if not check_file(path) then return end
	local file = io.lines(path)
	local content = {}
	local line_count = 0
	for line in file do
		table.insert(content, line)
		line_count = line_count + 1
	end
	file = io.open(path, "wb")
	for index, line in ipairs(content) do
		if (index > 1 or line_count <= 5) then
			file:write(line .. "\n")
		end
	end
end

function append_to_file(path, content)
	local file = io.open(path, "ab")
	if not file then return false end
	file:write(content)
	file:close()
	return true
end

function remove_from_file(path, data)
	if not check_file(path) then return false end
	local file = io.lines(path)
	local ret = false
	local content = {}
	for line in file do
		if not line:match(data) then
			table.insert(content, line)
		else
			ret = true
		end
	end
	file = io.open(path, "wb")
	for index, line in ipairs(content) do
		file:write(line .. "\n")
	end
	file:close()
	return ret
end

function touch_file(path)
	local file = io.open(path, "wb")
	if not file then return false end
	local content = file:write ""
	file:close()
	return true
end

-- Ubus Routines

function ubus(object, method, data)
	if not _ubus_connection then
		_ubus_connection = _ubus.connect()
		if not _ubus_connection then
			return nil
		end
	end

	if object and method then
		if type(data) ~= "table" then
			data = { }
		end
		return _ubus_connection:call(object, method, data)
	else
		return nil
	end
end

-- Ubus Logger

function logger(info)
	if info then  
		ubus("log", "write", { event = "uHTTP: " .. info }) 
	end
end

