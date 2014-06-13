class MiqHostSnmpSystem
	
	attr_reader	:invObj
	
	def initialize(ssMor, invObj)
		@invObj = invObj
		@ssMor = ssMor
	end
	
	def snmpSystem
		@invObj.getMoProp(@ssMor)
	end
	
end # class MiqHostSnmpSystem
