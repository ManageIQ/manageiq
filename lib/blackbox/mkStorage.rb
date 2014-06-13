$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")

require 'miq-metakit'
require 'tempfile'

module Manageiq
	class BlackBox
		METAKIT_CONFIG_FILE = "/metadata/miq.mk"
		
		def openMkDb
			unless @mk
				@mkost = OpenStruct.new(:tmp=>Tempfile.new("miqbbmk"), :updated=>false)
				if doesBBFileExist?(METAKIT_CONFIG_FILE)
					begin
						mkBinData = readData(METAKIT_CONFIG_FILE) 
						File.open(@mkost.tmp.path,'wb') {|f2| f2.write mkBinData }
					rescue => err
						$log.error "Error: BlackBox - open MKDB: [#{err}]"
					end
				end
				@mkost.tmp.close
				
				@mk = Metakit::Storage.open(@mkost.tmp.path, 1)
				
				# Create/Update views
				# NOTE: Keep timestamp on the first field for sorting purposes in Metakit::View::find_range_by_hash
				@mk.set_structure("info[version:S,guid:S],events[timestamp:L,table_name:S,event_type:S,status:S,hostId:S,event_data:S]")
				
				# Check for basic info view for version
				info = @mk.view("info")
				if info && info.count == 0
					info.build({"version"=>1.1, "guid"=>self.vmId})
				else
					info[0][:guid] = self.vmId.to_s if info[0][:guid].empty?
				end
				return @mk
			end
		end
		
		def closeMkDb
			if @mk
				@mk.commit
				@mk.close!
				
				# If the metakit db has been updated we need to write the updates
				# into othe blackbox.
				if @mkost.updated
					File.open(@mkost.tmp.path,'rb') {|f2|
						mkBinData = f2.read mkBinData
						writeData(METAKIT_CONFIG_FILE, mkBinData)
					}
					@mkost.tmp.close!
				end
			end
		end
		
		def recordEvent(dataHash)
			if self.exist?
				newHash = Hash.new
			
				# Remove certain fields that we want to record directly
				%w{ table_name status hostId }.each do |field|
					# Get the value by either String or Symbol
					value = dataHash.delete(field)
					value = dataHash.delete(field.to_sym) unless value
					newHash[field] = value if value	
				end
			
				# Record some other fields, but do not remove them
				%w{ timestamp event_type }.each do |field|
					# Get the value by either String or Symbol
					value = dataHash[field]
					value = dataHash[field.to_sym] unless value
					newHash[field] = value if value	
				end
			
				# Convert the rest to a YAML string for the eventData column
				newHash["event_data"] = YAML.dump(dataHash)
			
				# Record the event
				event = @mk.view("events")
				event.build(newHash)
				@mk.save
				@mkost.updated = true
			end
		end
		
		def self.recordEvent(vmName, dataHash)
			hostId = $miqHostCfg.hostId if $miqHostCfg
			eventValues = {
				"timestamp" => Time.now,
				"hostId"    => hostId
			}.merge(dataHash)
		
			bb = Manageiq::BlackBox.new(vmName)
			bb.recordEvent(eventValues)
			bb.close
		end
		
		#Temporary test code for checking the set of events in the blackbox
		def dumpEvents
			puts @mk.view("events").to_xml
		end
	end
end
