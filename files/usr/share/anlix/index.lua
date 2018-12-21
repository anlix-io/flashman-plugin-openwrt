require("uci")
json = require("json")

local function run_process(proc)
  local handle = io.popen(proc)
  local result = handle:read("*a")
  handle:close()
  return result
end

local function get_router_id()
  local result = run_process("sh -c \". /usr/share/functions/device_functions.sh; get_mac\"")
  -- remove \n
  return result:sub(1,-2)
end

local function is_authenticated()
  local result = run_process("sh -c \". /usr/share/functions/common_functions.sh; if is_authenticated; then echo 1; else echo 0; fi\"")
  -- remove \n
  result = result:sub(1,-2)

  if result == "1" then
    return true
  else
    return false
  end
end

local function get_router_secret()
  local result = run_process(". /usr/share/flashman_init.conf; echo $FLM_CLIENT_SECRET")
  -- remove \n
  return result:sub(1,-2)
end

local function get_flashman_server()
  local result = run_process(". /usr/share/flashman_init.conf; echo $FLM_SVADDR")
  -- remove \n
  return result:sub(1,-2)
end

local function check_file(path)
  local file = io.open(path, "rb")
  if not file then
    return false
  else
    file:close()
    return true
  end
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*all"
  file:close()
  return content
end

local function read_lines(path)
  if not check_file(path) then return nil end
  local file = io.lines(path)
  local content = {}
  for line in file do
    table.insert(content, line)
  end
  return content
end

local function trim_file(path)
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

local function append_to_file(path, content)
  local file = io.open(path, "ab")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function remove_from_file(path, data)
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

local function touch_file(path)
  local file = io.open(path, "wb")
  if not file then return false end
  local content = file:write "tmp"
  file:close()
  return true
end

local function write_firewall_file(blacklist_path)
  local lines = read_lines(blacklist_path)
  local firewall_file = io.open("/etc/firewall.user", "wb")
  for index, line in ipairs(lines) do
    local mac = line:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
    local rule = "iptables -I FORWARD -m mac --mac-source " .. mac .. " -j DROP"
    firewall_file:write(rule .. "\n")
  end
end

local function flashman_update(app_id, app_secret)
  local flashman_addr = get_flashman_server()
  -- Add App to the flashman base
  auth = {}
  auth["id"]=get_router_id()
  auth["secret"]=get_router_secret()
  auth["app_id"]=app_id
  auth["app_secret"]=app_secret
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

local function save_router_passwd_flashman(passwd, app_id, app_secret)
  local flashman_addr = get_flashman_server()
  auth = {}
  auth["id"]=get_router_id()
  auth["secret"]=get_router_secret()
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

local function get_router_passwd()
  local result = run_process("sh -c \". /usr/share/functions/api_functions.sh; echo $(get_flashapp_pass)\"")
  -- remove \n
  result = result:sub(1,-2)
  return result
end

local function save_router_passwd(pass)
  run_process("sh -c \". /usr/share/functions/api_functions.sh; set_flashapp_pass ".. pass .."\"")
  return true
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

local function error_handle(errid, errinfo, auth)
  resp = {}
  err = {}
  err["errno"] = errid
  err["errstr"] = errinfo
  if auth ~= nil then resp["auth"] = auth end
  resp["Error"] = err

  uhttpd.send("Status: 500 Internal Server Error\r\n")
  uhttpd.send("Content-Type: text/json\r\n\r\n")
  uhttpd.send(json.encode(resp))
end

function handle_request(env)
  local command = string.sub(env.PATH_INFO, 2)

  if env.REQUEST_METHOD == "POST" then
    local rlen, post_data = uhttpd.recv(8192) -- Max 8K in the post data!
    local data = json.decode(post_data)
    local app_protocol_ver = data.version
    local app_id = data.app_id
    local blacklist_path = "/tmp/blacklist_mac"

    if app_protocol_ver == nil then return end
    if app_id == nil then return end

    if tonumber(app_protocol_ver) > 2 then
      error_handle(1, "Invalid Protocol Version", nil)
      return
    end

    if command == "ping" then
      local passwd = get_router_passwd()
      -- no need to authenticate ping command
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")

      system_model = read_file("/tmp/sysinfo/model")
      if(system_model == nil) then system_model = "INVALID MODEL" end
      info = {}
      info["anlix_model"] = system_model
      info["protocol_version"] = 2.0
      if passwd ~= nil then
        info["router_has_passwd"] = 1
      else
        info["router_has_passwd"] = 0
      end
      uhttpd.send(json.encode(info))
      return
    end

    if tonumber(app_protocol_ver) == 1 then
      error_handle(1, "Invalid Protocol Version", nil)
      return
    end

    if not check_file("/tmp/anlix_authorized") then
      if is_authenticated then
        touch_file("/tmp/anlix_authorized")
      else
        error_handle(10, "Authorization Fail", nil)
        return
      end
    end

    local secret = get_key(app_id)
    local app_secret = data.app_secret

    if app_secret == nil or secret == nil then
      -- the app do not provide a secret, generate and send to flashman
      secret = gen_app_key(app_id)
      if secret == nil then
        -- error generating key, report to app
        error_handle(2, "Error generating secret for app", nil)
        return
      end
      if not flashman_update(app_id, secret) then
        error_handle(7, "Error updating flashman", nil)
        return
      end
    else
      -- we have key, compare secrets
      if app_secret ~= secret then
        error_handle(8, "Secret not match", nil)
        return
      end
    end

    -- authenticated successfully
    local resp = {}

    auth = {}
    auth["version"] = "1.0"
    auth["id_router"] = get_router_id()
    auth["app_secret"] = secret
    auth["flashman_addr"] = get_flashman_server()

    -- verify passwd
    local passwd = get_router_passwd()
    local router_passwd = data.router_passwd
    if passwd ~= nil then
      if router_passwd ~= passwd then
        error_handle(5, "Password not match", auth)
        return
      end
    end

    resp["auth"] = auth

    -- exec command
    if command == "change_passwd" then
      local new_passwd = data.new_passwd
      if new_passwd == nil then
        error_handle(3, "Invalid Parameters", auth)
        return
      end

      if passwd == nil then
        if not save_router_passwd_flashman(new_passwd, app_id, secret) then
          error_handle(4, "Error saving password", auth)
          return
        end
      end

      if not save_router_passwd(new_passwd) then
        error_handle(4, "Error saving password", auth)
        return
      else
        uhttpd.send("Status: 200 OK\r\n")
        uhttpd.send("Content-Type: text/json\r\n\r\n")
        resp["password_changed"] = 1
        uhttpd.send(json.encode(resp))
      end
    elseif command == "info" then
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")

      system_model = read_file("/tmp/sysinfo/model")
      if(system_model == nil) then system_model = "INVALID MODEL" end
      info = {}
      info["anlix_model"] = system_model
      resp["info"] = info
      uhttpd.send(json.encode(resp))
    elseif command == "wifi" then
      u = uci.cursor()
      wifi = u.get_all("wireless")

      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      resp["wireless"] = wifi
      uhttpd.send(json.encode(resp))
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
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      uhttpd.send(json.encode(resp))
    elseif command == "blacklist" then
      local mac = data.blacklist_mac
      local id = data.blacklist_id
      if mac == nil or not mac:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") then
        error_handle(11, "Error reading mac address")
        return
      end
      append_to_file(blacklist_path, mac .. "|" .. id .. "\n")
      write_firewall_file(blacklist_path)
      run_process("/etc/init.d/firewall restart")
      resp["blacklisted"] = 1
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      uhttpd.send(json.encode(resp))
    elseif command == "whitelist" then
      local mac = data.whitelist_mac
      if mac == nil or not mac:match("") then
        error_handle(11, "Error reading mac address")
        return
      end
      remove_from_file(blacklist_path, mac)
      write_firewall_file(blacklist_path)
      run_process("/etc/init.d/firewall restart")
      resp["whitelisted"] = 1
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      uhttpd.send(json.encode(resp))
    elseif command == "setHashCommand" then
      local hash = data.command_hash
      local timeout = data.command_timeout
      local epoch_timeout = os.time() + timeout - 1
      append_to_file("/root/to_do_hashes", hash .. " " .. epoch_timeout .. "\n")
      trim_file("/root/to_do_hashes")
      trim_file("/root/done_hashes")
      resp["is_set"] = 1
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      uhttpd.send(json.encode(resp))
    elseif command == "getHashCommand" then
      local hash = data.command_hash
      local is_done = remove_from_file("/root/done_hashes", hash)
      resp["command_done"] = is_done
      uhttpd.send("Status: 200 OK\r\n")
      uhttpd.send("Content-Type: text/json\r\n\r\n")
      uhttpd.send(json.encode(resp))
    else
      error_handle(6, "Command not implemented", auth)
    end
  end
end
