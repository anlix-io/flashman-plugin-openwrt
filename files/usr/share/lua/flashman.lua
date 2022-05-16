
local flashman={};

function flashman.get_router_id()
  local result = run_process("sh -c \". /usr/share/functions/device_functions.sh; get_mac\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_router_version()
  local result = run_process("sh -c \". /usr/share/functions/common_functions.sh; get_flashbox_version\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_router_release()
  local result = run_process("sh -c \". /usr/share/functions/common_functions.sh; get_flashbox_release\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_wifi_config()
  local result = run_process("sh -c \". /usr/share/functions/wireless_functions.sh; get_wifi_local_config\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_router_ssid()
  local result = run_process("sh -c \". /usr/share/functions/wireless_functions.sh; get_wifi_local_config | jsonfilter -e '@[\\\"local_ssid_24\\\"]'\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_mac_from_ip(ip)
  local result = run_process("sh -c \". /usr/share/functions/dhcp_functions.sh; get_device_mac_from_ip " .. ip .. "\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_wan_type()
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; get_wan_type\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_pppoe_user()
  local result = run_process("sh -c \"uci -q get network.wan.username\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_pppoe_pass()
  local result = run_process("sh -c \"uci -q get network.wan.password\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_mesh_master()
  local result = run_process("sh -c \". /usr/share/functions/mesh_functions.sh; get_mesh_master\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.set_wan_type(conn_type, user, pass)
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; set_wan_type " .. conn_type .. " " .. user .. " " .. pass .. " y &\"")
end

function flashman.set_pppoe_credentials(user, pass)
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; set_pppoe_credentials " .. user .. " " .. pass .. " y &\"")
end

function flashman.enable_bridge(switch, ip, gw, dns)
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; enable_bridge_mode y y " .. switch .. " " .. ip .. " " .. gw .. " " .. dns .. " &\"")
end

function flashman.update_bridge(switch, ip, gw, dns)
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; update_bridge_mode y " .. switch .. " " .. ip .. " " .. gw .. " " .. dns .. " &\"")
end

function flashman.disable_bridge()
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; disable_bridge_mode n y &\"")
end

function flashman.run_diagnostic()
  local result = run_process("sh -c \". /usr/share/functions/api_functions.sh; run_diagnostics_test\"")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.is_authenticated()
  local result = run_process("sh -c \". /usr/share/functions/common_functions.sh; if is_authenticated; then echo 1; else echo 0; fi\"")
  -- remove \n
  result = result:sub(1,-2)

  if result == "1" then
    return true
  else
    return false
  end
end

function flashman.get_router_passwd()
  local result = run_process("sh -c \". /usr/share/functions/api_functions.sh; get_flashapp_pass\"")
  -- remove \n
  result = result:sub(1,-2)
  if result == nil or result == "" then
    result = nil
  end
  return result
end

function flashman.save_router_passwd_local(pass)
  run_process("sh -c \". /usr/share/functions/api_functions.sh; set_flashapp_pass ".. pass .."\"")
  return true
end

function flashman.save_router_passwd_flashman(passwd, app_id, app_secret)
  local flashman_addr = flashman.get_server()
  auth = {}
  auth["id"]=flashman.get_router_id()
  auth["secret"]=flashman.get_router_secret()
  auth["app_id"]=app_id
  auth["app_secret"]=app_secret
  auth["router_passwd"]=passwd
  post_data = json.encode(auth)

  post_data = post_data:gsub("\"","\\\"")
  cmd_curl = "curl -s --tlsv1.2 -X POST -H \"Content-Type:application/json\" -d \"".. post_data  .."\" https://".. flashman_addr .."/deviceinfo/app/addpass?api=1"

  local result = run_process(cmd_curl)
  local jres = json.decode(result)

  if jres["is_registered"] == 1 then
    return true
  elseif jres["is_registered"] == nil then
    -- Legacy flashman doesn't have the url, can't set password on flashman
    return true
  else
    return false
  end
end

function flashman.get_router_secret()
  local result = run_process(". /usr/share/flashman_init.conf; echo $FLM_CLIENT_SECRET")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.get_server()
  local result = run_process(". /usr/share/flashman_init.conf; echo $FLM_SVADDR")
  -- remove \n
  return result:sub(1,-2)
end

function flashman.update(remote_addr, app_id, app_secret)
  local flashman_addr = flashman.get_server()
  -- Add App to the flashman base
  auth = {}
  auth["id"]=flashman.get_router_id()
  auth["secret"]=flashman.get_router_secret()
  auth["app_id"]=app_id
  auth["app_secret"]=app_secret
  auth["app_mac"]=flashman.get_mac_from_ip(remote_addr)
  post_data = json.encode(auth)

  post_data = post_data:gsub("\"","\\\"")
  cmd_curl = "curl -s --tlsv1.2 -X POST -H \"Content-Type:application/json\" -d \"".. post_data  .."\" https://".. flashman_addr .."/deviceinfo/app/add?api=1"

  local result = run_process(cmd_curl)

  local jres = json.decode(result)

  if jres["is_registered"] == 1 then
    return true
  else
    return false
  end
end


-- This function change the vlan configuration
function flashman.set_vlan_wan(wan_vlan)

  -- Open the vlan configuration file
  local vlan_config = read_file("/root/vlan_config.json")

  -- Check if the file is valid
  if vlan_config == nil then
    result = web.ERROR_OPEN_VLAN_CONFIG_FILE
    return result
  end

  -- Decode the json
  vlan_config = json.decode(vlan_config)

  -- Get the wan and cpu port number
  local wan_port = flashman.get_ports("wan")
  local cpu_port = flashman.get_ports("cpu")

  -- Loop through every key and value, ignoring the vlan of the wan
  local new_vlan_config = {}

  for key, value in pairs(vlan_config) do

    -- If it can find both the cpu and wan port in the vlan, ignore
    -- Otherwise, add to the new configuration
    if not (string.find(value, wan_port) ~= nil and 
        string.find(value, cpu_port) ~= nil) then
      new_vlan_config[key] = value
    end
  end

  -- Add the new configuration for wan
  -- If the wan_vlan came empty or nil, assign the default configuration
  if (wan_vlan == nil or wan_vlan == "")
    wan_vlan = run_process("sh -c \". /usr/share/functions/network_functions.sh; get_default_vlan \'wan\'\"")
    new_vlan_config[wan_vlan] = wan_port .. " " .. cpu_port .. "t"
  else
    new_vlan_config[wan_vlan] = wan_port .. "t " .. cpu_port .. "t"
  end

  -- Write the new configuration
  write_file("/root/vlan_config.json", json.encode(new_vlan_config))

  return "ok"
end

-- This function configures the vlan based on the 
-- configuration already provided
function flashman.configure_vlan()
  run_process("sh -c \". /usr/share/functions/network_functions.sh; update_vlan \'y\'\"")

  return
end

-- This function returns the vlan configuration json
function flashman.get_vlan_config()
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; get_vlan_config\"")
  
  if result == nil or result == "" then
    result = nil
  end

  return result
end

-- This function returns the ports in use
function flashman.get_ports(port_name)
  local result = run_process("sh -c \". /usr/share/functions/network_functions.sh; get_ports ".. port_name .."\"")
  
  if result == nil or result == "" then
    result = nil
  end

  return result
end

return flashman
