require_relative 'MiqBdb'
require_relative 'MiqBdbHash'
require_relative 'MiqBdbPage'

module MiqBerkeleyDB
  
  class MiqBdbUtil
	
    def initialize(fs = nil)
      @fs = fs
    end

  	def getkeys(fname)
  		bdb  = MiqBdb.new(fname, @fs)
  		keys = bdb.keys
  		bdb.close
  		return keys
		end
		
	end
end
