$:.push(File.dirname(__FILE__))

class MiqCustomFieldsManager
	
	attr_reader	:invObj
	
	def initialize(invObj)
        @invObj             = invObj
	    @sic                = invObj.sic
	
		@cfManager			= @sic.customFieldsManager
		raise "The customFieldsManager is not supported on this system." if !@cfManager
	end
	
	def field
		f = @invObj.getMoProp(@cfManager, 'field')
		return nil if !f
		return f.field
	end
	
	def addCustomFieldDef(name, moType=nil)
	end
	
	def removeCustomFieldDef(key)
	end
	
	def renameCustomFieldDef(key, name)
	end
	
	def setField(entity, key, value)
		@invObj.setField(@cfManager, entity, key, value)
	end
	
	def fieldDefByFilter(filter)
		@invObj.applyFilter(field, filter)
	end
	
	def getFieldKey(name, moType)
		fda = fieldDefByFilter('name' => name, 'managedObjectType' => moType)
    # Check the global fields (moType = nil) if we fail to find it by moType.
		fda = fieldDefByFilter('name' => name, 'managedObjectType' => nil) if fda.empty?
		raise "Definition of field #{name} for type #{moType}, not found" if fda.empty?
		return fda.first.key
	end
	
	def release
	end
	
end
