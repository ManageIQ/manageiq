
GB				= 1024 * 1024 * 1024

CONTAINING_AGGR	= "aggr1"
NEW_VOLUME		= "api_test_vol1"
VOL_SIZE_GB		= 10
NFS_PATH		= "/vol/#{NEW_VOLUME}"

TARGET_HOSTS	= [ SERVER ]
LOCAL_PATH		= NEW_VOLUME.tr('_', '-')		# Datastore names cannot contain underscores
ACCESS_MODE		= "readWrite"

begin
	
	#
	# Get the storage system on which you want to create the volume.
	#
	storageSystem = CimComputerSystem.find(:first)
	raise "Could not find storage system" if storageSystem.nil?
	puts "Got storageSystem: #{storageSystem.evm_display_name}"
	
	#
	# Get the management inteface for the storage system.
	#
	nrs = storageSystem.storage_managers.first		
	raise "Could not find manager entry for NetApp filer: #{storageSystem.evm_display_name}" if nrs.nil?
	puts "Found service entry for NetApp filer: #{storageSystem.evm_display_name} -> #{nrs.ipaddress}"
		
	#
	# Check to see if the volume already exists.
	#
	raise "Volume #{NEW_VOLUME} already exists" if nrs.has_volume?(NEW_VOLUME)
	puts "Volume #{NEW_VOLUME} does not exist, continuing..."
	
	#
	# Make sure there's enough free space in the aggregate for the new volume.
	#
	puts "Checking space on containing aggregate: #{CONTAINING_AGGR}"
	aggr_info = nrs.aggr_list_info(CONTAINING_AGGR)
	aggr_free_space = aggr_info.size_available.to_i
	raise "Insufficient free space in #{CONTAINING_AGGR}: #{aggr_free_space}" if aggr_free_space < VOL_SIZE_GB * GB
	puts "Containing aggregate: #{CONTAINING_AGGR} has sufficient free space"
	puts
		
	#
	# Create the volume within the given aggregate.
	#
	puts "Creating volume: #{NEW_VOLUME} in aggregate: #{CONTAINING_AGGR} on NAS server: #{storageSystem.evm_display_name}..."
	nrs.volume_create(NEW_VOLUME, CONTAINING_AGGR, "#{VOL_SIZE_GB}g")
	puts "done."
	puts
	
	###################################################################################################
	# The code below this point attaches the new volume, to one or more ESX hosts, as an NFS datastore.
	###################################################################################################
	
	#
	# Add the ESX hosts to the root hosts list for the NFS share.
	#
	puts "Adding the following to the root hosts list for #{NFS_PATH}: [ #{TARGET_HOSTS.join(', ')} ]"
	nrs.nfs_add_root_hosts(NFS_PATH, TARGET_HOSTS)
	puts "done."
	puts
	
	#
	# Get a list of the storage system's IP addresses. Multi-homed systems will have more than one.
	#
	addresses = nrs.get_addresses
	puts "Addresses: #{addresses.join(', ')}"
	puts
	
	#
	# For each host, attach the share as a datastore.
	#
	TARGET_HOSTS.each do |hostName|
		#
		# Get the VMDB instance for the host in question.
		#
		if (host = Host.find_by_hostname(hostName)).nil?
			puts "Could not find DB entry for host: #{hostName}"
			next
		else
			puts "Found DB entry for host: #{hostName}"
		end
		
		#
		# Get the EMS that manages the host.
		#
		if (hems = host.ext_management_system).nil?
			puts "Could not find EMS for host: #{hostName}"
			next
		else
			puts "Found EMS for host #{hostName} -> #{hems.name} (#{hems.hostname})"
		end
		puts
		
		#
		# Connect to the EMS.
		#
		puts "Connecting to EMS #{hems.hostname}..."
		begin
			vim = hems.connect
		rescue Exception => verr
			puts "Could not connect to ems - #{hems.hostname}"
			puts verr.to_s
			next
		end
		puts "done."
		
		#
		# Get the VIM pbject for the host.
		#
		begin
			miqHost = vim.getVimHost(hostName)
			puts "Got object for host: #{miqHost.name}"
		rescue => err
			puts "Could not find host: #{hostName}"
			next
		end
		puts
	
		#
		# Get the datastore system interface for the host.
		#
		miqDss = miqHost.datastoreSystem
	
		puts "Creating datastore: #{LOCAL_PATH} on host: #{hostName}..."
		#
		# Given that most Filers will be multihomed, we need to select an address that's
		# accessible by the host in question. Target hosts can be multihomed as well, making
		# IP selection even more complex.
		#
		# The simplest solution may be to try each of the filer's IPs, stopping when
		# createNasDatastore() succeeds.
		#
		addresses.each do |address|
			begin
				puts "Trying address: #{address}..."
				miqDss.createNasDatastore(address, NFS_PATH, LOCAL_PATH, ACCESS_MODE)
			rescue
				puts "Failed."
				next
			end
			puts "Success."
			break
		end
		
		miqHost.release
		puts "done."
		puts
		
		vim.disconnect
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
