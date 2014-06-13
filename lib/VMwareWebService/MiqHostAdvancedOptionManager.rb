class MiqHostAdvancedOptionManager
	
	attr_reader	:invObj
	
	def initialize(aomMor, invObj)
		@invObj = invObj
		@aomMor = aomMor
	end
	
	def setting
		@invObj.getMoProp(@aomMor)['setting']
	end
	
	def supportedOption
		@invObj.getMoProp(@aomMor)['supportedOption']
	end
	
	def queryOptions(name)
		@invObj.queryOptions(@aomMor, name)
	end
	
end # class MiqHostAdvancedOptionManager
