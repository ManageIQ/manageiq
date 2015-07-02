class MiqHostNetworkSystem
	
	attr_reader	:invObj
	
	def initialize(nsMor, invObj)
		@invObj = invObj
		@nsMor = nsMor
	end
	
	def networkInfo
		@invObj.getMoProp(@nsMor)
	end
	
	def refreshNetworkSystem
		@invObj.refreshNetworkSystem(@nsMor)
	end
	
end # class MiqHostNetworkSystem
