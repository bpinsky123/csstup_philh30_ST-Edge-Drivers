local capabilities = require('st.capabilities')
local capabilitydefs = {}
capabilitydefs.nodeId = capabilities["heartsample19211.deviceNetworkId"]

capabilitydefs.fingerprint = capabilities["heartsample19211.zwaveFingerprint"]
capabilitydefs.firmware = capabilities["heartsample19211.zwaveFirmware"]
capabilitydefs.security = capabilities["heartsample19211.zwaveSecurity"]


capabilitydefs.associationGroups = {}
capabilitydefs.associationGroups2 = capabilities["heartsample19211.zwaveAssociationGroups2"]
capabilitydefs.associationGroups3 = capabilities["heartsample19211.zwaveAssociationGroups3"]
capabilitydefs.associationGroups4 = capabilities["heartsample19211.zwaveAssociationGroups4"]
capabilitydefs.associationGroups.name = "heartsample19211.zwaveAssociationGroups"
capabilitydefs.associationGroups.capability = capabilities[capabilitydefs.associationGroups.name]

capabilitydefs.associationGroup = {}
capabilitydefs.associationGroup.name = "heartsample19211.zwaveGroupSelector"
capabilitydefs.associationGroup.capability = capabilities[capabilitydefs.associationGroup.name]

capabilitydefs.associationSet = {}
capabilitydefs.associationSet.name = "heartsample19211.zwaveAssociationSet"
capabilitydefs.associationSet.capability = capabilities[capabilitydefs.associationSet.name]

capabilitydefs.clearAssociation = capabilities["heartsample19211.zwaveClearAssociation"]

capabilitydefs.messageQueue = capabilities["heartsample19211.zwaveMessageQueue"]
capabilitydefs.commandClasses = capabilities["heartsample19211.zwaveCommandClasses"]
capabilitydefs.commandClasses2 = capabilities["heartsample19211.zwaveCommandClasses2"]
capabilitydefs.commandClasses3 = capabilities["heartsample19211.zwaveCommandClasses3"]
capabilitydefs.commandClasses4 = capabilities["heartsample19211.zwaveCommandClasses4"]
capabilitydefs.commandClasses5 = capabilities["heartsample19211.zwaveCommandClasses5"]
capabilitydefs.commandClasses6 = capabilities["heartsample19211.zwaveCommandClasses6"]
capabilitydefs.commandClasses7 = capabilities["heartsample19211.zwaveCommandClasses7"]
capabilitydefs.commandClasses8 = capabilities["heartsample19211.zwaveCommandClasses8"]
capabilitydefs.commandClasses9 = capabilities["heartsample19211.zwaveCommandClasses9"]
capabilitydefs.commandClasses10 = capabilities["heartsample19211.zwaveCommandClasses10"]
capabilitydefs.commandClasses11 = capabilities["heartsample19211.zwaveCommandClasses11"]
capabilitydefs.commandClasses12 = capabilities["heartsample19211.zwaveCommandClasses12"]
capabilitydefs.commandClasses13 = capabilities["heartsample19211.zwaveCommandClasses13"]
capabilitydefs.commandClasses14 = capabilities["heartsample19211.zwaveCommandClasses14"]
capabilitydefs.commandClasses15 = capabilities["heartsample19211.zwaveCommandClasses15"]
capabilitydefs.commandClasses16 = capabilities["heartsample19211.zwaveCommandClasses16"]
capabilitydefs.commandClasses17 = capabilities["heartsample19211.zwaveCommandClasses17"]
capabilitydefs.commandClasses18 = capabilities["heartsample19211.zwaveCommandClasses18"]
capabilitydefs.commandClasses19 = capabilities["heartsample19211.zwaveCommandClasses19"]
capabilitydefs.commandClasses20 = capabilities["heartsample19211.zwaveCommandClasses20"]

capabilitydefs.reset = capabilities["heartsample19211.zwaveReset"]

return capabilitydefs