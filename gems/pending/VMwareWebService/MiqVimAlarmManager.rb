$:.push(File.dirname(__FILE__))

class MiqVimAlarmManager
	
	attr_reader	:invObj
	
	def initialize(invObj)
        @invObj             = invObj
	    @sic                = invObj.sic
	
		@alarmManager		= @sic.alarmManager
		raise "The alarmManager is not supported on this system." if !@alarmManager
	end
	
	def getAlarm(entity=nil)
		amors = @invObj.getAlarm(@alarmManager, entity)
		return [] unless amors
		@invObj.getMoPropMulti(amors, 'info')
	end
	
	def release
	end
end
