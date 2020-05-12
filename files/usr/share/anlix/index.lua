require("uci")
require("lib")
json = require("json")
flashman = require("flashman") 
web = require("webHandle")
auth_provider = require("auth")
require("config")

local function write_firewall_file(blacklist_path)
	local lines = read_lines(blacklist_path)
	local firewall_file = io.open("/etc/firewall.user", "wb")
	for index, line in ipairs(lines) do
		local mac = line:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
		local rule = "iptables -I FORWARD -m mac --mac-source " .. mac .. " -j DROP"
		firewall_file:write(rule .. "\n")
	end
end

local function get_key(id)
	return read_file("/tmp/" .. id)
end

local function gen_app_key(id)
	local file = io.open("/tmp/" .. id, "wb")
	if not file then return nil end
	local secret = run_process("head -c 128 /dev/urandom | tr -dc 'a-zA-Z0-9'")
	file:write(secret)
	file:close()
	return secret
end

local function leases_to_json(leases)
	local result = {}
	for index, value in ipairs(leases) do
		local info = {}
		local values = {}
		for word in value:gmatch("%S+") do table.insert(values, word) end
		info["expire"] = values[1]
		info["mac"] = values[2]
		info["ip"] = values[3]
		info["id"] = values[4]
		table.insert(result, info)
	end
	return json.encode(result)
end

local function separate_fields(devices)
	local result = {}
	for index, info in ipairs(devices) do
		local device = {}
		device.mac = info:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
		device.id = info:match("|.+"):sub(2)
		table.insert(result, device)
	end
	return result
end

local function separate_keys(devices)
	local result = {}
	for index, info in ipairs(devices) do
		local mac = info:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
		local name = info:match("|.+"):sub(2)
		result[mac] = name
	end
	return result
end

function handle_request(env)
	logger("Connection from " .. env.REMOTE_ADDR)

	if env.PATH_INFO == nil then
		web.error_handle(web.ERROR_URL, nil)
		return
	end

	if not (env.REQUEST_METHOD == "POST") then
		web.error_handle(web.ERROR_URL, nil)
		return
	end

	local subcompos = string.find(env.PATH_INFO, "/", 2)
	local command = nil
	local subcommand = nil
	if subcompos == nil then 
		command = string.sub(env.PATH_INFO, 2)
	else
		command = string.sub(env.PATH_INFO, 2, subcompos-1)
		subcommand = string.sub(env.PATH_INFO, subcompos+1)
	end

	local rlen, post_data = uhttpd.recv(8192) -- Max 8K in the post data!
	if not post_data then
		web.error_handle(web.ERROR_DATA, nil)
		return
	end

	local status, data = pcall(function() return json.decode(post_data) end)
	if not status then
		web.error_handle(web.ERROR_DATA, nil)
		logger(data)
		return
	end

	local app_protocol_ver = data.version
	local app_id = data.app_id

	if app_protocol_ver == nil or app_id == nil then 
		web.error_handle(web.ERROR_DATA, nil)
		return
	end

	if tonumber(app_protocol_ver) > 3 then
		web.error_handle(web.ERROR_PROT_VER, nil)
		return
	end

	local auth_data = data.auth_provider
	if not (auth_data == nil) then
		if auth_provider.authenticate(auth_data) then
			logger("Provider Authorized as " .. auth_provider.get_user())
		else
			web.error_handle(web.ERROR_AUTH_PROVIDER, nil)
			return		
		end
	end
		
	if command == "config" then
		if auth_provider.is_authorized() then
			handle_config(subcommand, data)
			return
		else
			web.error_handle(web.ERROR_COMM_AUTH_PROVIDER, nil)
			return				
		end
	end

	local blacklist_path = "/tmp/blacklist_mac"

	if command == "ping" then
		local passwd = flashman.get_router_passwd()
		-- no need to authenticate ping command
		system_model = read_file("/tmp/sysinfo/model")
		if(system_model == nil) then system_model = "INVALID MODEL" end
		info = {}
		info["anlix_model"] = system_model
		info["protocol_version"] = 3.0
		info["diag_protocol_version"] = 1.0
		if passwd ~= nil then
			info["router_has_passwd"] = 1
		else
			info["router_has_passwd"] = 0
		end
		web.send_json(info)
		return
	elseif command == "getMulticastCache" then
		local cache = ubus("anlix_sapo", "get_cache")
		local resp = {}
		resp["ok"] = true
		if(cache ~= nil) then
			resp["multicast_cache"] = json.decode(cache)
		end
		web.send_json(resp)
		return
	end

	if tonumber(app_protocol_ver) == 1 then
		web.error_handle(web.ERROR_DATA, nil)
		return
	end

	if not check_file("/tmp/anlix_authorized") then
		if is_authenticated then
			touch_file("/tmp/anlix_authorized")
		else
			web.error_handle(web.ERROR_AUTH_FAIL, nil)
			return
		end
	end

	local secret = get_key(app_id)
	local app_secret = data.app_secret

	if app_secret == nil or secret == nil then
		-- the app do not provide a secret, generate and send to flashman
		secret = gen_app_key(app_id)
		if secret == nil then
			web.error_handle(web.ERROR_GEN_SECRET, nil)
			return
		end
		if not flashman.update(env.REMOTE_ADDR, app_id, secret) then
			web.error_handle(web.ERROR_FLASHMAN_UPDATE, nil)
			return
		end
	else
		-- we have key, compare secrets
		if app_secret ~= secret then
			web.error_handle(web.ERROR_SECRET_MATCH, nil)
			return
		end
	end

	-- authenticated successfully
	local resp = {}

	auth = {}
	auth["version"] = "1.0"
	auth["id_router"] = flashman.get_router_id()
	auth["app_secret"] = secret
	auth["flashman_addr"] = flashman.get_server()

	if command == "getLoginInfo" then
		resp["auth"] = auth
		local data = {}
		data["mac"] = flashman.get_router_id()
		data["ssid"] = flashman.get_router_ssid()
		resp["data"] = data
		web.send_json(resp)
		return
	end

	-- verify passwd
	local passwd = flashman.get_router_passwd()
	local router_passwd = data.router_passwd
	if passwd ~= nil then
		if router_passwd ~= passwd then
			web.error_handle(web.ERROR_ROUTER_PASSWD, nil)
			return
		end
	end

	resp["auth"] = auth

	-- exec command
	if command == "change_passwd" then
		local new_passwd = data.new_passwd
		if new_passwd == nil then
			web.error_handle(web.ERROR_PARAMETERS, auth)
			return
		end

		if passwd == nil then
			if not save_router_passwd_flashman(new_passwd, app_id, secret) then
				web.error_handle(web.ERROR_PASSWD_SAVE, auth)
				return
			end
		end

		if not save_router_passwd(new_passwd) then
			web.error_handle(web.ERROR_PASSWD_SAVE, auth)
			return
		else
			resp["password_changed"] = 1
			web.send_json(resp)
		end
	elseif command == "info" then
		system_model = read_file("/tmp/sysinfo/model")
		if(system_model == nil) then system_model = "INVALID MODEL" end
		info = {}
		info["anlix_model"] = system_model
		resp["info"] = info
		web.send_json(resp)
	elseif command == "wifi" then
		u = uci.cursor()
		wifi = u.get_all("wireless")
		resp["wireless"] = wifi
		web.send_json(resp)
	elseif command == "devices" then
		local leases = read_lines("/tmp/dhcp.leases")
		local result = leases_to_json(leases)
		local blacklist = {}
		local named_devices = {}
		if check_file(blacklist_path) then
			blacklist = read_lines(blacklist_path)
		end
		if check_file("/tmp/named_devices") then
			named_devices = read_lines("/tmp/named_devices")
		end
		local blacklist_info = separate_fields(blacklist)
		local named_devices_info = separate_keys(named_devices)
		resp["leases"] = result
		resp["blacklist"] = json.encode(blacklist_info)
		resp["named_devices"] = json.encode(named_devices_info)
		resp["origin"] = env.REMOTE_ADDR
		web.send_json(resp)
	elseif command == "blacklist" then
		local mac = data.blacklist_mac
		local id = data.blacklist_id
		if mac == nil or not mac:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") then
			web.error_handle(web.ERROR_READ_MAC, auth)
			return
		end
		append_to_file(blacklist_path, mac .. "|" .. id .. "\n")
		write_firewall_file(blacklist_path)
		run_process("/etc/init.d/firewall restart")
		resp["blacklisted"] = 1
		web.send_json(resp)
	elseif command == "whitelist" then
		local mac = data.whitelist_mac
		if mac == nil or not mac:match("") then
			web.error_handle(web.ERROR_READ_MAC, auth)
			return
		end
		remove_from_file(blacklist_path, mac)
		write_firewall_file(blacklist_path)
		run_process("/etc/init.d/firewall restart")
		resp["whitelisted"] = 1
		web.send_json(resp)
	elseif command == "setHashCommand" then
		local hash = data.command_hash
		local timeout = data.command_timeout
		local epoch_timeout = os.time() + timeout - 1
		append_to_file("/root/to_do_hashes", hash .. " " .. epoch_timeout .. "\n")
		trim_file("/root/to_do_hashes")
		trim_file("/root/done_hashes")
		resp["is_set"] = 1
		web.send_json(resp)
	elseif command == "getHashCommand" then
		local hash = data.command_hash
		local is_done = remove_from_file("/root/done_hashes", hash)
		resp["command_done"] = is_done
		web.send_json(resp)
	else
		web.error_handle(web.ERROR_CMD_UNKNOWN, auth)
	end
end
