flashman = require("flashman")

function handle_config(command, data)

	local app_protocol_ver = data.version

	if command == "diagnose" then
		-- Diagnose router and forward result to reply
		local data = flashman.run_diagnostic()
		web.send_json(data)
		return
	elseif command == "retrySapoFlashman" then
		-- Force a retry on sapo flashman communication
		local slave_mac = data.slave_mac
		flashman.retry_sapo_flashman(slave_mac)
		web.send_json({success = true})
		return
	elseif command == "getLoginInfo" then
		-- Send information for diagnose app login
		local resp = {}
		resp["mac"] = flashman.get_router_id()
		resp["version"] = flashman.get_router_version()
		resp["release"] = flashman.get_router_release()
		resp["conn_type"] = flashman.get_wan_type()
		resp["flashman"] = flashman.get_server()
		resp["wifi"] = flashman.get_wifi_config()
		resp["mesh_master"] = flashman.get_mesh_master()
		if (resp["conn_type"] == "pppoe") then
			resp["pppoe"] = {}
			resp["pppoe"]["user"] = flashman.get_pppoe_user()
			resp["pppoe"]["pass"] = flashman.get_pppoe_pass()
		elseif (resp["conn_type"] == "none") then
			local config_file = json.decode(read_file("/root/flashbox_config.json"))
			resp["bridge"] = {}
			resp["bridge"]["switch"] = (config_file["bridge_disable_switch"] == "y")
			local ip_config = config_file["bridge_fix_ip"]
			if (ip_config ~= nil and ip_config ~= "") then
				resp["bridge"]["ip"] = ip_config
				resp["bridge"]["gateway"] = config_file["bridge_fix_gateway"]
				resp["bridge"]["dns"] = config_file["bridge_fix_dns"]
			else
				resp["bridge"]["ip"] = ""
			end
		end
		web.send_json(resp)
		return
	elseif command == "getRoutersInfo" then
		local routers = ubus("anlix_sapo", "get_router_status")
		local resp = {}
		resp["ok"] = true;
		if(routers ~= nil and next(routers) ~= nil) then
			resp["routers"] = routers
		end
		web.send_json(resp)
		return
	elseif command == "nobridge" then
		-- Disable bridge and reply with ok so that
		web.send_json({success = true}) -- reply before changing network
		flashman.disable_bridge()
		return
	elseif command == "wan" then
		-- Change WAN type with given parameters
		local config_file = json.decode(read_file("/root/flashbox_config.json"))
		config_file["did_change_wan_local"] = "y"
		local conn_type = data.conn_type
		local local_conn_type = flashman.get_wan_type()
		if conn_type == "dhcp" then
			-- Change to DHCP, ignore if already in DHCP
			if local_conn_type == "dhcp" then
				web.send_json({success = true}) -- simply reply with success
				return
			end
			write_file("/root/flashbox_config.json", json.encode(config_file))
			web.send_json({success = true}) -- reply before changing network
			flashman.set_wan_type("dhcp", "none", "none")
		elseif conn_type == "pppoe" then
			-- Change to PPPoE, assume we always need to update credentials
			local user = data.user
			local pass = data.password
			if user == nil or pass == nil or user == "" or pass == "" then
				web.error_handle(web.ERROR_PARAMETERS, nil)
				return
			end
			write_file("/root/flashbox_config.json", json.encode(config_file))
			web.send_json({success = true}) -- reply before changing network
			if local_conn_type == "pppoe" then
				flashman.set_pppoe_credentials(user, pass)
			else
				flashman.set_wan_type("pppoe", user, pass)
			end
		elseif conn_type == "bridge" then
			local disable_switch = data.disable_switch
			if (disable_switch) then
				disable_switch = "y"
			else
				disable_switch = "n"
			end
			local ip = data.fix_ip
			local gateway = data.fix_gateway
			local dns = data.fix_dns
			if ip ~= nil and ip ~= "" then
				if gateway == nil or gateway == "" or dns == nil or dns == "" then
					-- Validate presence of gateway and dns parameters if using fix ip
					web.error_handle(web.ERROR_PARAMETERS, nil)
					return
				end
			end
			local local_config = read_file("/root/flashbox_config.json")
			local_config = json.decode(local_config)
			write_file("/root/flashbox_config.json", json.encode(config_file))
			web.send_json({success = true}) -- reply before changing network
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
