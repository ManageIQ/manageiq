class MiqHostFirewallSystem
	
	attr_reader	:invObj
	
	def initialize(fwsMor, invObj)
		@invObj = invObj
		@fwsMor = fwsMor
	end
	
	def firewallInfo
		@invObj.getMoProp(@fwsMor)['firewallInfo']
	end
	
	def getRulesByFilter(filter)
		@invObj.applyFilter(firewallInfo['ruleset'], filter)
	end
	
	def disableRuleset(rskey)
		@invObj.disableRuleset(@fwsMor, rskey)
	end
	
	def enableRuleset(rskey)
		@invObj.enableRuleset(@fwsMor, rskey)
	end
	
	def refreshFirewall
		@invObj.refreshFirewall(@fwsMor)
	end
	
	def updateDefaultPolicy(defaultPolicy)
		@invObj.updateDefaultPolicy(@fwsMor, defaultPolicy)
	end
	
end # class MiqHostFirewallSystem
