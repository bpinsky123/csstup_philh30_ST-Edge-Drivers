# Z-Wave Utility BP

A temporary diagnostic driver combining Z-Wave Explorer BP and Z-Wave Associator BP, based on work by philh30 and contributors. Switch a device back to its normal driver after use.

It displays device information and supported command classes. Devices supporting the standard Association command class can also display and change association groups. Devices without that command class use a diagnostics-only profile; multi-channel-association-only devices have not yet been verified. Sleepy devices may need to be awakened to complete queued requests.

**Caution:** Setting an association group replaces its existing node membership. Record the current members first and include any node that must remain, especially the hub in the Lifeline group. Removing the hub can stop unsolicited device status updates.

The driver uses manual-assignment fingerprints. Matching and profile changes must be tested on actual devices before release. Route and transmit statistics are not included.

## Command classes

`[S]` indicates a secure command class. Names may be abbreviated on the device card; the complete names are written to the driver log. If the list exceeds the display capacity, the last field shows how many entries are only in the log.

## Battery-powered devices

Devices that sleep may need a manual wake-up to process queued commands. The queue status says “Wake device to send” while work is waiting. Use the device manufacturer's wake-up procedure; operating a contact or switch does not necessarily generate a Z-Wave wake-up notification.

To inspect or change an association group:

1. Select the group and wake the device if the queue says it is waiting. Wait for the current members to be reported.
2. To change membership, enter the complete desired list, preserving existing members you want to keep, and submit it. Setting the group replaces the existing membership.
3. If commands are waiting, wake the device again. Wait for the follow-up group report to verify the result; an empty queue means commands were submitted, not that every operation succeeded.

Do not remove the hub from a Lifeline group unless you understand the consequences. Switch back to the device's normal driver after testing.
