#!/bin/sh
set -eu
cd "$(dirname "$0")"
namespace="heartsample19211"
capabilities="
zwaveDeviceInformation
zwaveCommandClasses
zwaveAssociationGroups
zwaveAssociationGroup
zwaveAssociationSet
zwaveMessageQueue
zwaveReset
"
for short_id in $capabilities; do
  id="$namespace.$short_id"
  smartthings capabilities:update "$id" --capability-version 1 -i "$id.capability.json"
  smartthings capabilities:presentation:update "$id" --capability-version 1 -i "$id.presentation.json"
done
