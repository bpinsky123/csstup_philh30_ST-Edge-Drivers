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
local splitAssocString = require "split_assoc_string"
local utilities = require "utilities"
local delay_send = require "delay_send"
local json = require "st.json"

local associationGroups = {}
local associationReportFragments = {}
local to_send_queue = {}
local to_send_display = {}

capabilities[capdefs.associationGroups.name] = capdefs.associationGroups.capability
capabilities[capdefs.associationGroup.name] = capdefs.associationGroup.capability
capabilities[capdefs.associationSet.name] = capdefs.associationSet.capability

local function update_queue_table(device)
  local this_device = device.device_network_id
  local queued_cmds
  if to_send_display[this_device] and #to_send_display[this_device] > 0 then
    queued_cmds = table.concat(to_send_display[this_device], '\n')
  else
    queued_cmds = 'No commands in queue'
  end
  device:emit_component_event(
    device.profile.components['queue'],
    capdefs.messageQueue.queue({value = queued_cmds}, {visibility = {displayed = false}})
  )
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

local function group_summary(group, data)
  local name = data.name or 'Unknown'
  local profile1 = data.profile1 and AssociationGrpInfo._reflect_profile1[data.profile1]
  local profile2_map = data.profile1 and AssociationGrpInfo._reflect_profile2[data.profile1]
  local profile2 = profile2_map and data.profile2 and profile2_map[data.profile2]
  if name == 'Unknown' and profile1 and profile2 then
    name = profile1 .. ': ' .. profile2
  end
  name = name:gsub(' control$', '')
  return string.format('%d %s', group, name)
end

local function update_group_table(device)
  local groups = associationGroups[device.device_network_id] or {}
  local group_numbers = {}
  for group, _ in pairs(groups) do
    table.insert(group_numbers, group)
  end
  table.sort(group_numbers)

  local group_text
  if #group_numbers == 0 then
    group_text = 'No association groups reported yet'
  else
    local summaries = {}
    for _, group in ipairs(group_numbers) do
      table.insert(summaries, group_summary(group, groups[group]))
    end
    group_text = 'Groups: ' .. table.concat(summaries, ' · ')
  end

  local evt = capabilities[capdefs.associationGroups.name].associationGroups({value = group_text})
  evt.visibility = {displayed = false}
  device:emit_event(evt)
end

local function update_device_info_table(device)
  local store = device.st_store or {}
  local function hex_or_unknown(value, width)
    return type(value) == 'number' and string.format('%0' .. width .. 'X', value) or 'Unknown'
  end
  local device_info = 'Mfr:' .. hex_or_unknown(store.zwave_manufacturer_id, 4)
    .. ' · Mdl:' .. hex_or_unknown(store.zwave_product_id, 4)
  local firmware = (store.zwave_version or {}).firmware or {}
  local fw_major = firmware.major
  local fw_minor = firmware.minor
  if fw_major and fw_minor then
    device_info = device_info .. ' · FW:' .. fw_major .. '.' .. string.format('%02d', fw_minor)
  end
  local security = {}
  for _, flag in pairs(store.zwave_security_flags or {}) do
    table.insert(security, flag)
  end
  device_info = device_info .. ' · Sec:' .. (#security > 0 and table.concat(security, ',') or 'unknown')

  local evt = capdefs.deviceInfo.deviceInformation({value = device_info})
  evt.visibility = {displayed = false}
  device:emit_event(evt)
  local cc_list = {cc.ASSOCIATION, cc.MULTI_CHANNEL_ASSOCIATION, cc.ASSOCIATION_GRP_INFO, cc.ASSOCIATION_COMMAND_CONFIGURATION}
  local cc_lines = {}
  for _, c in ipairs(cc_list) do
    if device:is_cc_supported(c) then
      table.insert(cc_lines, string.format('%02X %s', c, tostring(cc._classes[c] or 'Unknown')))
    end
  end
  evt = capdefs.commandClasses.commandClasses({
    value = #cc_lines > 0 and table.concat(cc_lines, ' · ') or 'No association command classes reported'
  })
  evt.visibility = {displayed = false}
  device:emit_event(evt)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function init(driver, device)
  if device:is_cc_supported(cc.WAKE_UP) then
    update_queue_table(device)
  end
  local ok, err = pcall(update_device_info_table, device)
  if not ok then
    log.warn(string.format("Unable to update device information: %s", tostring(err)))
  end
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
  associationGroups[this_device] = nil
  associationReportFragments[this_device] = nil
  to_send_queue[this_device] = nil
end

--- Association:Report handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.Association.Report
local function finish_association_report(device, group, max_nodes, nodes, report_kind, reports_to_follow)
  local this_device = device.device_network_id
  associationReportFragments[this_device] = associationReportFragments[this_device] or {}
  local key = report_kind .. ':' .. group
  local fragment = associationReportFragments[this_device][key] or { nodes = {} }

  fragment.max = max_nodes or fragment.max
  for _, node in ipairs(nodes) do
    table.insert(fragment.nodes, node)
  end

  if (tonumber(reports_to_follow) or 0) > 0 then
    associationReportFragments[this_device][key] = fragment
    return
  end

  associationReportFragments[this_device][key] = nil
  associationGroups[this_device] = associationGroups[this_device] or {}
  associationGroups[this_device][group] = associationGroups[this_device][group] or {}
  associationGroups[this_device][group].max = fragment.max or 'Unknown'
  associationGroups[this_device][group].nodes = table.concat(fragment.nodes, ',')

  local node_list = associationGroups[this_device][group].nodes
  if node_list == '' then node_list = 'None' end
  local requested_group = device:get_latest_state('setAssociationGroup', capdefs.associationGroup.name, 'associationGroup')
  if group == requested_group then
    local event = capabilities[capdefs.associationSet.name].associationSet({value = node_list})
    event.visibility = {displayed = false}
    event.state_change = true
    device:emit_component_event(
      device.profile.components['setAssociationGroup'],
      event
    )
  end
  update_group_table(device)
end

local function assoc_report(driver, device, command)
  log.trace('Association Report received')
  local group = tonumber(command.args.grouping_identifier)
  if not group then return end
  local nodes = {}
  for _, node in ipairs(command.args.node_ids or {}) do
    table.insert(nodes, string.format('%02X', node))
  end
  finish_association_report(device, group, tostring(command.args.max_nodes_supported or 'Unknown'), nodes,
    'association', command.args.reports_to_follow)
end

--- MultiChannelAssociation:Report handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.MultiChannelAssociation.Report
local function multi_assoc_report(driver, device, command)
  log.trace('Association Report received')
  local group = tonumber(command.args.grouping_identifier)
  if not group then return end
  local nodes = {}
  for _, node in ipairs(command.args.node_ids or {}) do
    table.insert(nodes, string.format('%02X', node))
  end
  for _, node in ipairs(command.args.multi_channel_nodes or {}) do
    table.insert(nodes, string.format('%02X:%02X', node.multi_channel_node_id, node.end_point))
  end
  finish_association_report(device, group, tostring(command.args.max_nodes_supported or 'Unknown'), nodes,
    'multi', command.args.reports_to_follow)
end

--- AssociationGroupInfo:GroupNameReport handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.AssociationGrpInfo.AssociationGroupNameReport
local function assoc_name_report(driver, device, command)
  log.trace('Association Group Name Report received')
  local group = tonumber(command.args.grouping_identifier)
  local group_name = command.args.name
  local this_device = device.device_network_id
  associationGroups[this_device] = associationGroups[this_device] or {}
  associationGroups[this_device][group] = associationGroups[this_device][group] or {}
  associationGroups[this_device][group].name = group_name
  update_group_table(device)
end

--- AssociationGroupInfo:GroupInfoReport handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.AssociationGrpInfo.AssociationGroupInfoReport
local function assoc_info_report(driver, device, command)
  log.trace('Association Group Info Report received')
  local this_device = device.device_network_id
  associationGroups[this_device] = associationGroups[this_device] or {}
  local updated = false
  for _, group_info in ipairs(command.args.groups or {}) do
    local group = tonumber(group_info.grouping_identifier)
    if group then
      associationGroups[this_device][group] = associationGroups[this_device][group] or {}
      associationGroups[this_device][group].profile1 = group_info.profile1
      associationGroups[this_device][group].profile2 = group_info.profile2
      updated = true
    end
  end
  if updated then update_group_table(device) end
end

--- Association:GroupingsReport handler
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command st.zwave.CommandClass.Association.GroupingsReport
local function assoc_group_report(driver, device, command)
  log.trace('Association Groupings Report received')
  local groups = command.args.supported_groupings
  local supports_multi = device:is_cc_supported(cc.MULTI_CHANNEL_ASSOCIATION)
  local cmds = {}
  local desc = {}
  local this_device = device.device_network_id
  associationGroups[this_device] = associationGroups[this_device] or {}
  if groups > 0 then
    for i=1,groups,1 do
      associationGroups[this_device][i] = associationGroups[this_device][i] or {}
      if supports_multi then
        table.insert(cmds,MultiChannelAssociation:Get({grouping_identifier = i}))
        table.insert(desc,'Multi-Channel Assoc Get - Group ' .. i)
      else
        table.insert(cmds,Association:Get({grouping_identifier = i}))
        table.insert(desc,'Assoc Get - Group ' .. i)
      end
      if device:is_cc_supported(cc.ASSOCIATION_GRP_INFO) then
        table.insert(cmds,AssociationGrpInfo:AssociationGroupNameGet({grouping_identifier = i}))
        table.insert(cmds,AssociationGrpInfo:AssociationGroupInfoGet({grouping_identifier = i}))
        table.insert(desc,'Assoc Group Name Get - Group ' .. i)
        table.insert(desc,'Assoc Group Info Get - Group ' .. i)
      end
    end
  else
    update_group_table(device)
  end
  send_queue(device,cmds,1,desc)
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
  device:send(WakeUp:NoMoreInformation({}))
  to_send_queue[this_device] = nil
  to_send_display[this_device] = nil
  update_queue_table(device)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function get_association_group(driver, device, command)
  local group = tonumber(command.args.associationGroup)
  local supports_multi = device:is_cc_supported(cc.MULTI_CHANNEL_ASSOCIATION)
  local cmds = {}
  local desc = {}
  log.debug(string.format('Fetching data for Association Group %s',group))
  local group_event = capabilities[capdefs.associationGroup.name].associationGroup({value = group})
  group_event.visibility = {displayed = false}
  group_event.state_change = true
  device:emit_component_event(device.profile.components['setAssociationGroup'], group_event)

  local nodes_event = capabilities[capdefs.associationSet.name].associationSet({value = 'Fetching nodes...'})
  nodes_event.visibility = {displayed = false}
  nodes_event.state_change = true
  device:emit_component_event(device.profile.components['setAssociationGroup'], nodes_event)
  if supports_multi then
    table.insert(cmds,MultiChannelAssociation:Get({grouping_identifier = group}))
    table.insert(desc,'Multi-Channel Assoc Get - Group ' .. group)
  else
    table.insert(cmds,Association:Get({grouping_identifier = group}))
    table.insert(desc,'Assoc Get - Group ' .. group)
  end
  if device:is_cc_supported(cc.ASSOCIATION_GRP_INFO) then
    table.insert(cmds,AssociationGrpInfo:AssociationGroupNameGet({grouping_identifier = group}))
    table.insert(cmds,AssociationGrpInfo:AssociationGroupInfoGet({grouping_identifier = group}))
    table.insert(desc,'Assoc Group Name Get - Group ' .. group)
    table.insert(desc,'Assoc Group Info Get - Group ' .. group)
  end
  send_queue(device,cmds,1,desc)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function refresh_handler(driver,device,command)
  -- Pull-down refresh is delivered to every component that exposes refresh.
  -- The main component performs the one complete association scan.
  if command.component ~= 'main' then
    return
  end

  local supports_multi = device:is_cc_supported(cc.MULTI_CHANNEL_ASSOCIATION)
  -- Device information is supplementary. Older versions of the runtime can
  -- expose one of the fields used by the HTML table as userdata; do not let
  -- that prevent the association queries below from being sent.
  local ok, err = pcall(update_device_info_table, device)
  if not ok then
    log.warn(string.format("Unable to update device information: %s", tostring(err)))
  end
  local group = 1
  if not device:get_latest_state('setAssociationGroup',capdefs.associationGroup.name,'associationGroup') then
    device:emit_component_event(device.profile.components['setAssociationGroup'],capabilities[capdefs.associationGroup.name].associationGroup({value = 1},{visibility = {displayed = false}}))
  else
    group = device:get_latest_state('setAssociationGroup',capdefs.associationGroup.name,'associationGroup')
  end
  device:emit_component_event(device.profile.components['setAssociationGroup'],capabilities[capdefs.associationSet.name].associationSet({value = 'Fetching nodes...'},{visibility = {displayed = false}}))
  local cmds = {Association:GroupingsGet({})}
  local desc = {'Assoc Groupings Get'}
  if supports_multi then
    table.insert(cmds,MultiChannelAssociation:Get({grouping_identifier = group}))
    table.insert(desc,'Multi-Channel Assoc Get - Group ' .. group)
  else
    table.insert(cmds,Association:Get({grouping_identifier = group}))
    table.insert(desc,'Assoc Get - Group ' .. group)
  end
  if device:is_cc_supported(cc.ASSOCIATION_GRP_INFO) then
    table.insert(cmds,AssociationGrpInfo:AssociationGroupNameGet({grouping_identifier = group}))
    table.insert(cmds,AssociationGrpInfo:AssociationGroupInfoGet({grouping_identifier = group}))
    table.insert(desc,'Assoc Group Name Get - Group ' .. group)
    table.insert(desc,'Assoc Group Info Get - Group ' .. group)
  end
  send_queue(device,cmds,1,desc)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function association_set_handler(driver,device,command)
  local cmds = {}
  local desc = {}
  local nodes = command.args.associationSet
  local supports_multi = device:is_cc_supported(cc.MULTI_CHANNEL_ASSOCIATION)
  local event = capabilities[capdefs.associationSet.name].associationSet({value = nodes})
  event.visibility = {displayed = false}
  event.state_change = true
  device:emit_component_event(device.profile.components['setAssociationGroup'], event)
  local node_list,multi_nodes = splitAssocString(nodes,',',5,false,supports_multi)
  local group = device:get_latest_state('setAssociationGroup',capdefs.associationGroup.name,'associationGroup')
  if supports_multi then
    cmds = {MultiChannelAssociation:Remove({grouping_identifier = group, node_ids = {}, multi_channel_nodes = {}})}
    desc = {'Multi-Channel Assoc Remove - Group ' .. group}
  else
    cmds = {Association:Remove({grouping_identifier = group, node_ids = {}})}
    desc = {'Assoc Remove - Group ' .. group}
  end
  if (#node_list + #multi_nodes) > 0 then
    local nodes_desc = ''
    for _,n in ipairs(node_list) do
      nodes_desc = nodes_desc .. ((#nodes_desc > 0) and ',' or '') .. string.format('%02X',n)
    end
    for _,n in ipairs(multi_nodes) do
      nodes_desc = nodes_desc .. ((#nodes_desc > 0) and ',' or '') .. string.format('%02X',n.multi_channel_node_id) .. ':' .. string.format('%02X',n.end_point)
    end
    if supports_multi then
      table.insert(cmds,MultiChannelAssociation:Set({grouping_identifier = group, node_ids = node_list, multi_channel_nodes = multi_nodes}))
      table.insert(desc,'Multi-Channel Assoc Set - Group ' .. group .. ' Nodes: ' .. nodes_desc)
    else
      table.insert(cmds,Association:Set({grouping_identifier = group, node_ids = node_list}))
      table.insert(desc,'Assoc Set - Group ' .. group .. ' Nodes: ' .. nodes_desc)
    end
  end
  if supports_multi then
    table.insert(cmds,MultiChannelAssociation:Get({grouping_identifier = group}))
    table.insert(desc,'Multi-Channel Assoc Get - Group ' .. group)
  else
    table.insert(cmds,Association:Get({grouping_identifier = group}))
    table.insert(desc,'Assoc Get - Group ' .. group)
  end
  send_queue(device,cmds,2,desc)
end

--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function reset(driver,device,command)
  local this_device = device.device_network_id
  to_send_queue[this_device] = nil
  to_send_display[this_device] = nil
  update_queue_table(device)
end

local driver_template = {
  zwave_handlers = {
    [cc.ASSOCIATION] = {
      [Association.REPORT] = assoc_report,
      [Association.GROUPINGS_REPORT] = assoc_group_report,
    },
    [cc.ASSOCIATION_GRP_INFO] = {
      [AssociationGrpInfo.ASSOCIATION_GROUP_NAME_REPORT] = assoc_name_report,
      [AssociationGrpInfo.ASSOCIATION_GROUP_INFO_REPORT] = assoc_info_report,
    },
    [cc.MULTI_CHANNEL_ASSOCIATION] = {
      [MultiChannelAssociation.REPORT] = multi_assoc_report,
    },
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
    [capdefs.associationGroup.capability.ID] = {
      [capdefs.associationGroup.capability.commands.getAssociationGroup.NAME] = get_association_group,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler,
    },
    [capdefs.associationSet.capability.ID] = {
      [capdefs.associationSet.capability.commands.setNodes.NAME] = association_set_handler,
    },
    [capdefs.reset.ID] = {
      [capdefs.reset.commands.reset.NAME] = reset,
    },
  },
  NAME = "zwub-associator",
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
local associator = ZwaveDriver("zwub-associator", driver_template)
associator:run()