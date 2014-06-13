$:.push("#{File.dirname(__FILE__)}/../../disk")
$:.push("#{File.dirname(__FILE__)}/../../fs/MiqFS")
$:.push("#{File.dirname(__FILE__)}/../util/win32")

require 'ostruct'
require 'MiqDisk'
require 'MiqFS'
require 'VMPlatformMount'
require 'system_path_win'   # Used to check for Windows system partition

class VMMount
  attr_reader :disk
  
	def initialize(filename, ost=nil)
	    $log.debug "Initializing VMMount, filename: #{filename}" if $log
		@mountDrive = nil
		@diskInfo = OpenStruct.new
		@ost = OpenStruct.new if !ost
		@disk = nil
		@fs = nil

		# Use the MIQ functions to load virtual disk image
		# Check if there is a flat file and redirect to the proper name
		# TODO: This function should be improved to open the current file and check for the
		#       redirection.  Right now it just looks for the expected flat filename.
		$log.debug "vmmount called for disk image: [#{filename}]"
		@diskInfo.fileName = getMountFile(filename)
		
		@platMount = VMPlatformMount.new(@diskInfo, @ost)
		@platMount.preMount
		begin
			@disk = MiqDisk.getDisk(@diskInfo)
			raise "Failed to open disk: #{@diskInfo.fileName}" if @disk == nil
			
			@parts = @disk.getPartitions
			raise "No Partitions found on disk: #{@diskInfo.fileName}" if @parts == nil
			
			$log.debug "VMMount mounting partitions of #{filename}" if $log
			@parts.each do |p|
				fsPartitions = MiqFS.getFS(p)
				unless fsPartitions.nil?
					# Always set the fs pointer to the first partition so we return something.
					@fs = fsPartitions if @fs.nil?

					# If the systemRoot does not throw an error then we found it
					# and should return this fs.  Otherwise, continue looking.
					begin
						Win32::SystemPath.systemRoot(fsPartitions)
						@fs = fsPartitions
						break
					rescue => err
						#$log.warn "No Windows partition here."
					end
				end
			end
			$log.debug "vmmount complete for: [#{filename}]"
		rescue => err
			@platMount.postMount
			raise err
		end
	end
	
	def getMountFile(fn)
      file_miq = File.join(File.dirname(fn), File.basename(fn, ".*") + ".miq")
      return file_miq if File.exists?(file_miq)
	  return fn
	end
	
	def unMountImage
		if @disk
		    @disk.close
		    @platMount.postMount
		end
	end
	
	def getMountDrive
	  return @fs if @fs
		@mountDrive
	end

	def mounted?
	  return true unless getMountDrive.nil?
	  return false
	end
end
