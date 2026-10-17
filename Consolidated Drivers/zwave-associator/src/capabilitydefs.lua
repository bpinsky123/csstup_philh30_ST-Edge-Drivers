local capabilities = require('st.capabilities')
local capabilitydefs = {}

capabilitydefs.deviceInfo = capabilities['heartsample19211.zwaveDeviceInformation']

capabilitydefs.associationGroups = {}
capabilitydefs.associationGroups.name = "heartsample19211.zwaveAssociationGroups"
capabilitydefs.associationGroups.capability = capabilities[capabilitydefs.associationGroups.name]

capabilitydefs.associationGroup = {}
capabilitydefs.associationGroup.name = "heartsample19211.zwaveAssociationGroup"
capabilitydefs.associationGroup.capability = capabilities[capabilitydefs.associationGroup.name]

capabilitydefs.associationSet = {}
capabilitydefs.associationSet.name = "heartsample19211.zwaveAssociationSet"
capabilitydefs.associationSet.capability = capabilities[capabilitydefs.associationSet.name]

capabilitydefs.commandClasses = capabilities["heartsample19211.zwaveCommandClasses"]

capabilitydefs.messageQueue = capabilities["heartsample19211.zwaveMessageQueue"]

capabilitydefs.reset = capabilities["heartsample19211.zwaveReset"]

return capabilitydefs