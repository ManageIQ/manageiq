require 'rubygems'
require 'log4r'

class MiqUtil
	def self.runcmd(cmd_str, test=false)
		if not test
			rv = `#{cmd_str} 2>&1`
			if $? != 0
				raise rv
			end
		else
			rv = "#{cmd_str}: Test output"
		end

		rv
	end
end
