-- Copyright 2022 philh30
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local capdefs = require "capabilitydefs"
local cc = require "st.zwave.CommandClass"
local ZwaveDriver = require "st.zwave.driver"
local defaults = require "st.zwave.defaults"
local log = require "log"
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version=3 })
--- @type st.zwave.CommandClass.MultiChannelAssociation
local MultiChannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version=4 })
--- @type st.zwave.CommandClass.AssociationGrpInfo
local AssociationGrpInfo = (require "st.zwave.CommandClass.AssociationGrpInfo")({ version=3 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version=1 })
--- @type st.zwave.CommandClass.Version
local Version = (require "st.zwave.CommandClass.Version")({ version=3 })
local splitAssocString = require "split_assoc_string"
local utilities = require "utilities"
local delay_send = require "delay_send"
local json = require "st.json"

local to_send_queue = {}
local to_send_display = {}

local function table_row(row_items)
  local row = '<tr>'
  for _,item in pairs(row_items) do
    row = row .. '<td>' .. (item or '') .. '</td>'
  end
  row = row .. '</tr>'
  return row
end

local function update_queue_table(device)
  local this_device = device.device_network_id
  local queued_cmds = '<table style="font-size:65%;width:100%">'
  if to_send_display[this_device] and #to_send_display[this_device] > 0 then
    for _, d in ipairs(to_send_display[this_device]) do
      queued_cmds = queued_cmds .. table_row({d})
    end
  else
    queued_cmds = queued_cmds .. table_row({'No commands in queue'})
  end
  queued_cmds = queued_cmds .. '</table>'
  device:emit_component_event(device.profile.components['queue'],capdefs.messageQueue.queue({value = queued_cmds},{visibility = {displayed = false}}))
end

local function send_queue(device,commands,delay,description)
  local this_device = device.device_network_id
  for _, s in ipairs(description) do
    log.trace(string.format('Queued z-wave command: %s',s))
  end
  if device:is_cc_supported(cc.WAKE_UP) then
    to_send_queue[this_device] = to_send_queue[this_device] or {}
    for _,cmd in ipairs(commands) do
      table.insert(to_send_queue[this_device],cmd)
    end
    to_send_display[this_device] = to_send_display[this_device] or {}
    for _,d in ipairs(description) do
      table.insert(to_send_display[this_device],d)
    end
    update_queue_table(device)
  else
    delay_send(device,commands,delay)
  end
end

local function update_device_info_table(device)
  local store = device.st_store or {}

  local function hex_or_unknown(value, width)
    return type(value) == "number" and string.format("%0" .. width .. "X", value) or "Unknown"
  end

  local function safe_text(value, fallback)
    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
      return tostring(value)
    end
    return fallback or "Unavailable"
  end

  local diagnostic_capabilities = {
    fingerprint = capdefs.fingerprint,
    firmware = capdefs.firmware,
    security = capdefs.security,
  }
  local function emit_info(attribute, value)
    local event = diagnostic_capabilities[attribute][attribute]({value = value})
    event.visibility = {displayed = false}
    local ok, err = pcall(device.emit_event, device, event)
    if not ok then
      log.warn("Unable to emit " .. attribute .. ": " .. tostring(err))
    end
  end

  local fingerprint = hex_or_unknown(store.zwave_manufacturer_id, 4)
    .. "-" .. hex_or_unknown(store.zwave_product_type, 4)
    .. "-" .. hex_or_unknown(store.zwave_product_id, 4)

  local firmware = (store.zwave_version or {}).firmware or {}
  local firmware_text = "Unavailable"
  if firmware.major and firmware.minor then
    firmware_text = safe_text(firmware.major) .. "." .. safe_text(firmware.minor)
  end

  local security_flags = {}
  for _, flag in pairs(store.zwave_security_flags or {}) do
    if type(flag) == "string" or type(flag) == "number" then
      table.insert(security_flags, tostring(flag))
    end
  end
  local security = #security_flags > 0 and table.concat(security_flags, ", ") or "Unknown"

  emit_info("fingerprint", fingerprint)
  emit_info("firmware", firmware_text)
  emit_info("security", security)


  local node_id = tostring(device.device_network_id)
  local node_event = capdefs.nodeId.deviceNetworkId(node_id)
  local node_ok, node_err = pcall(
    device.emit_component_event,
    device,
    device.profile.components.main,
    node_event
  )
  if not node_ok then
    log.warn("Unable to emit Device Network ID: " .. tostring(node_err))
  end

  local cc_lines = {}
  for _, endpoint in ipairs(device.zwave_endpoints or {}) do
    for _, command_class in ipairs(endpoint.command_classes or {}) do
      if command_class.supported then
        local name = safe_text(cc._classes[command_class.value], "Unknown")
        table.insert(cc_lines, string.format(
          "%02X %s%s",
          command_class.value,
          name,
          command_class.secure and " / secure" or ""
        ))
      end
    end
  end
  table.sort(cc_lines)
  local command_class_pages = {
    capdefs.commandClasses,
    capdefs.commandClasses2,
    capdefs.commandClasses3,
    capdefs.commandClasses4,
    capdefs.commandClasses5,
    capdefs.commandClasses6,
    capdefs.commandClasses7,
    capdefs.commandClasses8,
  }
  for page, capability in ipairs(command_class_pages) do
    local first = ((page - 1) * 2) + 1
    local page_lines = {}
    for index = first, math.min(first + 1, #cc_lines) do
      table.insert(page_lines, cc_lines[index])
    end
    local value = #page_lines > 0 and table.concat(page_lines, "\n") or "No additional command classes"
    local command_class_event = capability.commandClasses({value = value})
    command_class_event.visibility = {displayed = false}
    local classes_ok, classes_err = pcall(device.emit_event, device, command_class_event)
    if not classes_ok then
      log.warn("Unable to emit command classes page " .. page .. ": " .. tostring(classes_err))
    end
  end
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function init(driver, device)
  if device:is_cc_supported(cc.WAKE_UP) then
    update_queue_table(device)
  end
  update_device_info_table(device)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function do_configure(driver, device)
  --device:refresh()
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function added(driver, device)
  device:refresh()
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function removed(driver, device)
  local this_device = device.device_network_id
  to_send_queue[this_device] = nil
end

--- WakeUp:Notification handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.WakeUp.Notification
local function wakeup_notification(driver, device, command)
  log.trace('WakeUp Notification received')
  local this_device = device.device_network_id
  for _, cmd in ipairs(to_send_queue[this_device] or {}) do
    device:send(cmd)
  end
  to_send_queue[this_device] = nil
  to_send_display[this_device] = nil
  update_queue_table(device)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function refresh_handler(driver,device,command)
  update_device_info_table(device)local cmds = {}
  local desc = {}
  table.insert(cmds,Version:Get({}))
  send_queue(device,cmds,1,desc)
end

local driver_template = {
  zwave_handlers = {
    [cc.WAKE_UP] = {
        [WakeUp.NOTIFICATION] = wakeup_notification,
    },
  },
  supported_capabilities = {
    capabilities.refresh,
  },
  lifecycle_handlers = {
    doConfigure = do_configure,
    added = added,
    removed = removed,
    init = init,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler,
    },
  },
  NAME = "zwub-utility-belt",
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
local explorer = ZwaveDriver("zwub-explorer", driver_template)
explorer:run()
