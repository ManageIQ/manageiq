$:.push(File.dirname(__FILE__))

class  MiqVimCustomizationSpecManager
	
	attr_reader	:invObj
	
	def initialize(invObj)
        @invObj             = invObj
	    @sic                = invObj.sic
	
		@csManager			= @sic.customizationSpecManager
		raise "The customizationSpecManager is not supported on this system." unless @csManager
	end
	
	def encryptionKey
		rv = @invObj.getMoProp(@csManager, 'encryptionKey')
		return nil unless rv
		return rv['encryptionKey']
	end
	
	def info
		rv = @invObj.getMoProp(@csManager, 'info')
		return nil unless rv
		return rv['info']
	end
	
	def doesCustomizationSpecExist(name)
		rv = @invObj.doesCustomizationSpecExist(@csManager, name)
		return rv == 'true'
	end
	
	def getCustomizationSpec(name)
		@invObj.getCustomizationSpec(@csManager, name)
	end

	def getAllCustomizationSpecs
		specs = info
		return [] if specs.nil?

		specs = specs.dup.to_miq_a
		specs.each { |s| s['spec'] = getCustomizationSpec(s['name'].to_s).spec }
		return specs
	end

	def createCustomizationSpec(item)
		@invObj.createCustomizationSpec(@csManager, item)
	end
	
	def createCustomizationSpecFromXml(specItemXml)
		item = xmlToCustomizationSpecItem(specItemXml)
		createCustomizationSpec(item)
	end
	
	def deleteCustomizationSpec(name)
		@invObj.deleteCustomizationSpec(@csManager, name)
	end
	
	def customizationSpecItemToXml(item)
		@invObj.customizationSpecItemToXml(@csManager, item)
	end
	
	def xmlToCustomizationSpecItem(specItemXml)
		@invObj.xmlToCustomizationSpecItem(@csManager, specItemXml)
	end
	
	def release
	end
	
end
