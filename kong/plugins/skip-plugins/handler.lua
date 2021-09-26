local kong = kong
local ngx = require "ngx"
local BasePlugin = require "kong.plugins.base_plugin"
local runloop = require "kong.runloop.handler"
local update_time = ngx.update_time
local now = ngx.now
local kong_global = require "kong.global"
local PHASES = kong_global.phases
local skipPlugins = BasePlugin:extend()
local portal_auth = require "kong.portal.auth"
local currentpluginName = 'skip-plugins'

skipPlugins.PRIORITY = 3000

function skipPlugins:new()
  skipPlugins.super.new(self, "skip-plugins")
end

-- Get Current Time
local function get_now_ms()
  update_time()
  return now() * 1000 -- time is kept in seconds with millisecond resolution.
end

-- Split using delimiter
local function split(string, delimiter)
   local result = {};
   for match in (string..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
   end
   return result;
end

-- Remove spaces from Beginning and Ending of String
local function trim(headerValue)
   return string.gsub(headerValue,"^%s*(.-)%s*$", "%1")
end

-- Get Blocked plugin Name 
local function getBlockedPluginName(conf, reqPluginName)
local pluginNames = split(conf.plugin_names,  ",+")
  for _,pluginName in pairs(pluginNames) do
    local blockedPluginName = trim(pluginName)
    if(reqPluginName == blockedPluginName) then
      kong.log("####  skip-plugins: Blocked Plugin Name : ##### ", blockedPluginName )
      return reqPluginName
    end
  end
end

-- flush the response
local function flush_delayed_response(ctx)
  ctx.delay_response = false

  if type(ctx.delayed_response_callback) == "function" then
    ctx.delayed_response_callback(ctx)
    return -- avoid tail call
  end

  kong.response.exit(ctx.delayed_response.status_code,
                     ctx.delayed_response.content,
                     ctx.delayed_response.headers)
end

-- validate the skipped PluginName
local function validatePluginName(conf)
    local pluginNames = trim(conf.plugin_names) ;
    if(pluginName == nil) then
      kong.log.err("#### skip-plugins: Plugin Name is Empty")
      return kong.response.exit(400, { message = "skip-plugins : pluginName is Empty" })
    end
end

-- Method to override the access phase
local function kongaccess(conf)
  validatePluginName(conf)
  local ctx = ngx.ctx
  ctx.is_proxy_request = true
  if not ctx.KONG_ACCESS_START then
    ctx.KONG_ACCESS_START = get_now_ms()
    if ctx.KONG_REWRITE_START and not ctx.KONG_REWRITE_ENDED_AT then
      ctx.KONG_REWRITE_ENDED_AT = ctx.KONG_ACCESS_START
      ctx.KONG_REWRITE_TIME = ctx.KONG_REWRITE_ENDED_AT - ctx.KONG_REWRITE_START
    end
  end
  kong_global.set_phase(kong, PHASES.access)
  runloop.access.before(ctx)
  ctx.delay_response = true
  local old_ws = ctx.workspace
  local plugins_iterator = runloop.get_plugins_iterator()
  for plugin, plugin_conf in plugins_iterator:iterate("access", ctx) do
    kong.log("#### skip-plugins: Plugin Name :" , plugin.name)
    if(plugin.name ~= currentpluginName) then
      local blockedPluginName = getBlockedPluginName(conf, plugin.name)
      kong.log("#### skip-plugins: Blocked Plugin Name :" , blockedPluginName)
      if(plugin.name ~= blockedPluginName) then
        kong.log("#### skip-plugins:  Plugin Name : " , plugin.name , " is not blocked ")
        if plugin.handler._go then
          ctx.ran_go_plugin = true
        end

        if not ctx.delayed_response then
          kong_global.set_named_ctx(kong, "plugin", plugin.handler)
          kong_global.set_namespaced_log(kong, plugin.name)

          local err = coroutine.wrap(plugin.handler.access)(plugin.handler, plugin_conf)
          if err then
            kong.log.err(err)
            ctx.delayed_response = {
              status_code = 500,
              content     = { message  = "An unexpected error occurred" },
            }
          end

          local ok, err = portal_auth.verify_developer_status(ctx.authenticated_consumer)
          if not ok then
            ctx.delay_response = false
            return kong.response.exit(401, { message = err })
          end

          kong_global.reset_log(kong)
        end
        ctx.workspace = old_ws
      end
    end
  end

    if ctx.delayed_response then
      ctx.KONG_ACCESS_ENDED_AT = get_now_ms()
      ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START
      ctx.KONG_RESPONSE_LATENCY = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_PROCESSING_START

      return flush_delayed_response(ctx)
    end

    ctx.delay_response = false

    if not ctx.service then
      ctx.KONG_ACCESS_ENDED_AT = get_now_ms()
      ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START
      ctx.KONG_RESPONSE_LATENCY = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_PROCESSING_START

      return kong.response.exit(503, { message = "no Service found with those values"})
    end

    runloop.access.after(ctx)

    ctx.KONG_ACCESS_ENDED_AT = get_now_ms()
    ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START

    -- we intent to proxy, though balancer may fail on that
    ctx.KONG_PROXIED = true

    if kong.ctx.core.buffered_proxying then
      return buffered_proxy(ctx)
    end
  runloop.access.after(ngx.ctx)
  return ngx.exit(ngx.OK)
end

-- This will execute when the client request hits the plugin
function skipPlugins:access(conf)
  kong.log("#### skip-plugins:  Executing Access Phase")
  kongaccess(conf)
end

return skipPlugins

