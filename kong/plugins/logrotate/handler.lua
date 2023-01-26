--
--
-- User: ungle
-- Date: 2023/1/24
-- Time: 12:00
--
--
local constants = require "kong.constants"
local timer = ngx.timer
local os_date = os.date
local os_remove = os.remove
local os_rename = os.rename
local lfs = require "lfs"
local ngx = ngx
local ngx_time = ngx.time
local ngx_update_time = ngx.update_time
local process = require("ngx.process")
local signal = require("resty.signal")
local shell = require("resty.shell")

local periods_seconds = {
    "minute" = 60,
    "hour" = 3600,
    "day" = 86400,
    "month" = 2628000
    "year" = 31536000
}
local dbless = kong.configuration.database == "off"
local hybrid_mode = kong.configuration.role == "control_plane" or
                    kong.configuration.role == "data_plane"

local skip_timers = {}

local LogrotateHandler = {
    PRIORITY = -1, 
    VERSION = "0.1.0",
}

local function file_size(file)
    local attr = lfs.attributes(file)
    if attr then
        return attr.size
    end
    return 0
end

local function sort_oldest(a,b)
    local mod_a = lfs.attributes(a)["modification"]
    local mod_b = lfs.attributes(b)["modification"]

    return mod_a < mod_b

end

local function remove_oldest_files(file_path,max_kept)

    local file_table = {}
    local count = 0

    local split_index =string.find(string.reverse(file_path),"/")

    local path = string.sub(file_path,1,split_index)
    local prefix = string.sub(split_index+1)

     for file in lfs.dir(path) do
        if(string.sub(file,1,#prefix) == prefix) then
            table.insert(file_table,file)
            count = count+1
        end
    end

    if count <= max_kept then 
        return
    else
        count = count - max_kept
    end

    table.sort(file_table, sort_oldest)

    for i=1,max_kept do
        ok, err = os_remove(file_table[i])
        if err then 
            kong.log.err("remove log file: ", new_file," failed: ", err)

    end

end

local function send_singnal()
    local pid = process.get_master_pid()
    local ok, err = signal.kill(pid, signal.signum("USR1"))
    if not ok then
        kong.log.err("send signal for reopening file failed: ", err)
    end
end


local function compress_file(file_path)

    local com_path = file_path .. ".tar.gz"
    local cmd = str_format("tar -zcf %s %s", file_path,com_path)
    local ok, stdout, stderr, reason, status = shell.run(cmd)

    if not ok then
        kong.log.err("compress log file ", new_filename,
                       " failed, "," reason: ", reason)
        return
    end

end


local function rename_file(file_path,compression)
    local new_path = file_path .. os_date("%Y%m%d%H%M%S", now_time)

    local ok, err = os_rename(file_path, new_path)
    if not ok then
        kong.log.err("move file failed: ", err)
        return
    end

    send_singnal()

    if compression then
        compress_file(new_path)
    end

    return

end

local function rotate_file(log_paths,compression,max_kept)
    for i,v in ipairs(log_paths) do
        rename_file(v,conf.compression)
        remove_oldest_files(v,max_kept)
    end


end 

local function rotate(premature,conf,name)
    if premature or skip_timers[name] == true  then 
        return
    end

    rotate_file(conf.log_paths,conf.compression,conf.max_kept)

end

local function get_plugin_config()
    for plugin, err in kong.db.plugins:each(1000) do
    if err then
      kong.log.warn("error fetching plugin: ", err)
    end

    if plugin.name == "logrotate" then
      return plugin.config
    end
  end
end

local function refresh_timer(premature)
    if premature then
       return
    end

    plugin_conf = get_plugin_config()

    local rotate_period = plugin_conf.rotate_interval * periods_seconds[plugin_conf.rotate_interval_unit]

    if not skip_timers[rotate_period_name]  then
        for k, v in pairs(skip_timers) do
            if  v == false then
                skip_timers[k] = true
                break
            end
        end

        skip_timers[rotate_period] = false
        timer.every(rotate_period, rotate,plugin_conf,rotate_period)

    end

end




function LogrotateHandler:init_worker(plugin_conf)
    local rotate_period = plugin_conf.rotate_interval * periods_seconds[plugin_conf.rotate_interval_unit]

    if ngx.worker.id() ==0 then
        timer.every(rotate_period, rotate_file,plugin_conf,rotate_period)
        skip_timers[rotate_period] = false

        local wait = kong.configuration.db_update_frequency
        if hybrid_mode then 
            wait = wait * 2
        end

        if not dbless then
            timer.every(wait,refresh_timer)
        end

end

function LogrotateHandler:log(plugin_conf)
    if ngx.worker.id() ~=0 then 
        return
    end

    local rotate_table = {}
    for i,v in ipairs(plugin_conf.log_paths) do
        if file_size(v) > plugin_conf.max_size then 
            table.insert(rotate_table,v)
        end
    end

    if next(rotate_table) ~= nil then
        rotate_file(rotate_table,plugin_conf.compression,plugin_conf.max_kept)
    end
end

return LogrotateHandler