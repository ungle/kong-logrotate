
--
--
-- User: ungle
-- Date: 2023/1/24
-- Time: 12:00
--
--

local typedefs = require "kong.db.schema.typedefs"
local PERIODS = {"minute", "hour", "day", "month", "year" }

-- Grab pluginname from module name

local schema = {
    name = "logrotate",
    fields = {

        { consumer = typedefs.no_consumer },
        { protocols = typedefs.protocols_http },
        { config = {

            type = "record",
            fields = {

                { rotate_interval = {type = "integer", gt = 0 , default = 1}}
                { rotate_interval_unit =  {type = "string",default = "day",one_of = PERIODS } },
                { log_paths =  { 
                type = "set", 
                default = { "/usr/local/kong/logs/access.log","/usr/local/kong/logs/error.log" }, 
                elements = { type = "string" } 
            }},
                { max_kept =  { type = "integer", gt = 0 , default = 1 }, },
                { max_size =  { type = "integer", gt = 0 }, },
                { compression = { type = "boolean", required = true, default = false }, },
            },
        },
        },
    },
    
}

return schema

