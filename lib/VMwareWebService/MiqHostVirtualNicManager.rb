class MiqHostVirtualNicManager
	
	attr_reader	:invObj
	
	def initialize(vnmMor, invObj)
		@invObj = invObj
		@vnmMor = vnmMor
	end
	
	def info
		@invObj.getMoProp(@vnmMor)['info']
	end
	
	def queryNetConfig(nicType)
		@invObj.queryNetConfig(@vnmMor, nicType)
	end
	
	def candidateVnicsByType(nicType)
		return [] if (nc = queryNetConfig(nicType)).nil?
		return (nc.candidateVnic || [])
	end
	
	def selectedVnicsByType(nicType)
		return [] if (nc = queryNetConfig(nicType)).nil?
		return (nc.selectedVnic || [])
	end
	
	def deselectVnicForNicType(nicType, device)
		@invObj.deselectVnicForNicType(@vnmMor, nicType, device)
	end
	
	def selectVnicForNicType(nicType, device)
		@invObj.selectVnicForNicType(@vnmMor, nicType, device)
	end
	
end # class MiqHostVirtualNicManager
