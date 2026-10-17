local capabilities = require('st.capabilities')
local capabilitydefs = {}
capabilitydefs.nodeId = capabilities["heartsample19211.deviceNetworkId"]

capabilitydefs.fingerprint = capabilities["heartsample19211.zwaveFingerprint"]
capabilitydefs.firmware = capabilities["heartsample19211.zwaveFirmware"]
capabilitydefs.security = capabilities["heartsample19211.zwaveSecurity"]


capabilitydefs.associationGroups = {}
capabilitydefs.associationGroups.name = "heartsample19211.zwaveAssociationGroups"
capabilitydefs.associationGroups.capability = capabilities[capabilitydefs.associationGroups.name]

capabilitydefs.associationGroup = {}
capabilitydefs.associationGroup.name = "heartsample19211.zwaveAssociationGroup"
capabilitydefs.associationGroup.capability = capabilities[capabilitydefs.associationGroup.name]

capabilitydefs.associationSet = {}
capabilitydefs.associationSet.name = "heartsample19211.zwaveAssociationSet"
capabilitydefs.associationSet.capability = capabilities[capabilitydefs.associationSet.name]


capabilitydefs.messageQueue = capabilities["heartsample19211.zwaveMessageQueue"]
capabilitydefs.commandClasses = capabilities["heartsample19211.zwaveCommandClasses"]
capabilitydefs.commandClasses2 = capabilities["heartsample19211.zwaveCommandClasses2"]
capabilitydefs.commandClasses3 = capabilities["heartsample19211.zwaveCommandClasses3"]
capabilitydefs.commandClasses4 = capabilities["heartsample19211.zwaveCommandClasses4"]
capabilitydefs.commandClasses5 = capabilities["heartsample19211.zwaveCommandClasses5"]
capabilitydefs.commandClasses6 = capabilities["heartsample19211.zwaveCommandClasses6"]
capabilitydefs.commandClasses7 = capabilities["heartsample19211.zwaveCommandClasses7"]
capabilitydefs.commandClasses8 = capabilities["heartsample19211.zwaveCommandClasses8"]

capabilitydefs.reset = capabilities["heartsample19211.zwaveReset"]

return capabilitydefs