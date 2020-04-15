function handle_config(command, data)

	local app_protocol_ver = data.version

	if command == "diagnose" then
		-- Diagnose router and forward result to reply
		local data = run_diagnostic()
		web.send_json(data)
		return
	elseif command == "nobridge" then
		-- Disable bridge and reply with ok so that
		web.send_json(json.encode({success = true})) -- reply before changing network
		flashman.disable_bridge()
		return
	elseif command == "wan" then
		-- Change WAN type with given parameters
		local conn_type = data.conn_type
		local local_conn_type = flashman.get_wan_type()
		if conn_type == "dhcp" then
			-- Change to DHCP, ignore if already in DHCP
			if local_conn_type == "dhcp" then
				web.error_handle(web.ERROR_NO_CHANGE, nil)
				return
			end
			web.send_json(json.encode({success = true})) -- reply before changing network
			flashman.set_wan_type("dhcp", "", "")
		elseif conn_type == "pppoe" then
			-- Change to PPPoE, assume we always need to update credentials
			local user = data.user
			local pass = data.password
			if user == nil or pass == nil or user == "" or pass == "" then
				web.error_handle(web.ERROR_PARAMETERS, nil)
				return
			end
			web.send_json(json.encode({success = true})) -- reply before changing network
			flashman.set_wan_type("pppoe", user, pass)
		elseif conn_type == "bridge" then
			local disable_switch = data.disable_switch
			local ip = data.fix_ip
			local gateway = data.fix_gateway
			local dns = data.fix_dns
			if gateway == nil or gateway == "" or dns == nil or dns == "" then
				-- Validate presence of gateway and dns parameters if using fix ip
				web.error_handle(web.ERROR_PARAMETERS, nil)
				return
			end
			local local_config = read_file("/root/flashbox_config.json")
			local_config = json.decode(local_config)
			web.send_json(json.encode({success = true})) -- reply before changing network
			if local_config.bridge_mode ~= "y" then
				-- Enable bridge mode
				flashman.enable_bridge(disable_switch, ip, gateway, dns)
			else
				-- Update bridge parameters, assume we always need to update
				flashman.update_bridge(disable_switch, ip, gateway, dns)
			end
		end
	end

end
