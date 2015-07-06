class MiqHostServiceSystem
	
	attr_reader	:invObj
	
	def initialize(ssMor, invObj)
		@invObj = invObj
		@ssMor = ssMor
	end
	
	def serviceInfo
		@invObj.getMoProp(@ssMor)['serviceInfo']
	end
	
	def getServicesByFilter(filter)
		@invObj.applyFilter(serviceInfo['service'], filter)
	end
	
	def refreshServices
		@invObj.refreshServices(@ssMor)
	end
	
	def restartService(skey)
		@invObj.restartService(@ssMor, skey)
	end
	
	def startService(skey)
		@invObj.startService(@ssMor, skey)
	end
	
	def stopService(skey)
		@invObj.stopService(@ssMor, skey)
	end
	
	def uninstallService(skey)
		@invObj.uninstallService(@ssMor, skey)
	end
	
	def updateServicePolicy(skey, policy)
		@invObj.updateServicePolicy(@ssMor, skey, policy)
	end
	
end # class MiqHostServiceSystem
