$:.push("#{File.dirname(__FILE__)}/../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../discovery")
$:.push(File.dirname(__FILE__))

require 'net/ssh'
require 'net/sftp'
require 'timeout'
require 'aws-sdk'
require 'ostruct'
require 'tmpdir'
require 'MiqVm'
require 'PortScan'
require 'Ec2Payload'

class Ec2Extractor
	
	CATEGORIES	= ["accounts", "services", "software", "system"]
	
	LOG_LEVELS	= {
		"DEBUG"			=> Log4r::DEBUG,
		"INFO"			=> Log4r::INFO,
		"WARN"			=> Log4r::WARN,
		"ERROR"			=> Log4r::ERROR,
		"FATAL"			=> Log4r::FATAL,
		Log4r::DEBUG	=> "DEBUG",
		Log4r::INFO		=> "INFO",
		Log4r::WARN		=> "WARN",
		Log4r::ERROR	=> "ERROR",
		Log4r::FATAL	=> "FATAL"
	}
	
	EXTRACTOR32		= File.join(File.dirname(__FILE__), "local-extractor/local-extractor32")
	TARGET32		= File.join("/tmp", File.basename(EXTRACTOR32))
	EXTRACTOR64		= File.join(File.dirname(__FILE__), "local-extractor/local-extractor64")
	TARGET64		= File.join("/tmp", File.basename(EXTRACTOR64))
	IMAGE_DIR		= "/nmnt/tmp_image_dir"
	KNOWN_HOSTS		= "/root/.ssh/known_hosts"
	BUCKET_NAME		= "miq-extract"
	OPTIMEOUT		= 30
	
	SSH_RETRYS		= 15
	SSH_SLEEP		= 20
	SSH_PORT		= 22
	RDP_PORT		= 3389
	PORT_TIMEOUT	= 5
	
	def initialize(logFile)
		@logFile = logFile
		
		@args = Ec2Payload.userData
		
		#
		# Default log level set by caller.
		#
		if (@logLevelStr = @args[:log_level])
			$log.level = LOG_LEVELS[@logLevelStr]
		else
			@logLevelStr = LOG_LEVELS[$log.level]
		end
		
		@categories = @args[:categories] || CATEGORIES
		
		$log.info "Log level: #{@logLevelStr}"
		$log.info %Q/Categories: #{@categories.join(", ")}/
		
		@timeStampStr = @args[:timeStamp]
		if !@timeStampStr
			timeStamp = Time.now.utc
			@timeStampStr = "TS:" + (timeStamp.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % timeStamp.usec).to_str
		end
		
		@pkFile	= File.join(Dir.tmpdir, $$.to_s)

		@inputBucket	= @args[:miq_bucket_in]
		@outputBucket	= @args[:miq_bucket_out]

		$log.info "Input bucket:   #{@inputBucket}"
		$log.info "Output bucket:  #{@outputBucket}"
		$log.info "Payload object: #{@args[:payload]}"

		AWS.config({
			:access_key_id     => @args[:access_key_id],
			:secret_access_key => @args[:secret_access_key]
		})

		@payloadName	= @args[:payload]
		@logTarget		= @payloadName.tr("/", "-") + "-log.txt"

		#
		# Read the payload data from the input bucket and decode it.
		#
		@payload = s3object(@inputBucket, @payloadName).read
		@payload = Ec2Payload.decode(@payload)
		
		$log.info "ec2-download-bundle version: #{`ec2-download-bundle --version | line`.chomp}"
		$log.info "ec2-unbundle version: #{`ec2-unbundle --version | line`.chomp}"

		`mkdir -p #{IMAGE_DIR}`

		@ec2 = AWS::EC2.new(:access_key_id => @payload[:account_info][:access_key_id], :secret_access_key => @payload[:account_info][:secret_access_key])

		$log.info "Reading image information..."
		@amiHash = {}
		images = @ec2.images
		images.each do |ami|
			@amiHash[ami.location]	= ami # hash by location
			@amiHash[ami.id]		= ami # and image ID
		end
		$log.info "done."
		
		File.open(@pkFile, "w+", 0600) { |f| f.write(@payload[:account_info][:private_key]) }
		@keyFiles = [@pkFile]
	end # def initialize

	def s3
		@s3 ||= AWS::S3.new
	end

	def s3object(bucket, name)
		bucket = s3bucket(bucket) unless bucket.kind_of?(AWS::S3::Bucket)
		bucket.objects[name]
	end

	def s3bucket(name)
		@s3buckets ||= {}
		@s3buckets[name] ||= s3.buckets[name]
	end

	def extract
		#
		# If we're given the image IDs of the AMIs to scan,
		# construct a list of the manifest paths of those AMIs.
		#
		amiPaths = []
		@payload[:images].each do |id|
			if !(ami = @amiHash[iid])
				$log.error "Image: #{iid} not found"
				next
			end
			amiPaths << ami.location
		end if @payload[:images]
		#
		# If we're given a list of manifest paths of AMIs to scan,
		# merge that list with the list we created from the image IDs.
		#
		amiPaths |= @payload[:manifests] if @payload[:manifests]
		
		$log.info "Scan start."
		$log.info "AMIs to scan: #{amiPaths.length}"

		#
		# Go through the list of manifest paths and scan each AMI.
		#
		amiNum = 1
		amiPaths.each do |vmId|
			#
			# Get the bucket and S3 object ID for the manifest.
			#
			bucket, manifest = vmId.split("/", 2)
			bucket, manifest = manifest.split("/", 2) if bucket == ""
			
			s3prefix = File.join(@timeStampStr, vmId.tr("/", "-"))

			$log.info "++++++++++++++++++++++++"
			$log.info "AMI# #{amiNum}, Loc: #{vmId}"
			$log.info "Bucket: #{bucket}"
			$log.info "Manifest: #{manifest}"
			
			s3object(@outputBucket, File.join(s3prefix, "ami_location")).write(vmId, :content_type => "text/plain")
			s3object(@outputBucket, File.join(s3prefix, "START")).write(Time.now.utc.to_s, :content_type => "text/plain")

			catch :next do
				begin
					unless (ami = @amiHash[vmId])
						$log.info "#{vmId} not found, skipping."
						throw :next
					end
					if ami.root_device_type == :instance_store
						bundleExtract(vmId, bucket, manifest, s3prefix)
					elsif ami.root_device_type == :ebs
						# Until we can implement EBS extract
						raise "Ebs root device, falling back to instance extract"
					else
						$log.info "Unrecognized root device type: #{ami.root_device_type}, skipping."
						throw :next
					end
				rescue Exception => aerr
					$log.info aerr.to_s
					#
					# Here, if the ami is launchable, we can launch an instance of it
					# to extract its data.
					#
					begin
						if (ami = @amiHash[vmId])
							Timeout::timeout(OPTIMEOUT * 60) { instanceLaunchExtract(ami, s3prefix) }
							throw :next
						end
					rescue Timeout::Error
						extractError("Scan timed out after #{OPTIMEOUT} minutes", s3prefix)
						throw :next
					rescue => ileErr
						extractError(ileErr.to_s, s3prefix, ileErr)
						throw :next
					end
					extractError("Cannot access #{vmId}", s3prefix)
					throw :next
				end
			end # catch :next
			$log.info "------------------------"

			s3object(@outputBucket, File.join(s3prefix, "END")).write(Time.now.utc.to_s, :content_type => "text/plain")
			
			amiNum += 1
		end # amiPaths.each do
		
		$log.info "Instances to scan: #{@payload[:instances].length}"
		
		@payload[:instances].each do |iid|
			s3prefix = File.join(@timeStampStr, iid)
			catch :next do
				begin
					$log.info "++++++++++++++++++++++++"
					$log.info "AMI# #{amiNum}, Instance id: #{iid}"
					
					ri = @ec2.instances[iid]
					if !ri || !ri.reservationSet || !ri.reservationSet.item[0].instancesSet || ri.reservationSet.item[0].instancesSet.item.empty?
						raise "Instance #{iid} does not exist"
					end
						
					is = ri.reservationSet.item[0].instancesSet.item
					
					instObj = is[0]
				
					$log.info "Image ID: #{instObj.imageId}"
					if !(image = @amiHash[instObj.imageId])
						$log.warn "Cannot get image information for instance #{iid}"
					else
						vmId = image.imageLocation + "." + iid
						s3prefix = File.join(@timeStampStr, vmId.tr("/", "-"))
						$log.info "Base image location: #{image.imageLocation}"
						s3object(@outputBucket, File.join(s3prefix, "ami_location")).write(image.imageLocation, :content_type => "text/plain")
					end
					
					s3object(@outputBucket, File.join(s3prefix, "instance_id")).write(iid, :content_type => "text/plain")
					s3object(@outputBucket, File.join(s3prefix, "START")).write(Time.now.utc.to_s, :content_type => "text/plain")
					
					instanceExtract(instObj, s3prefix)
				rescue Timeout::Error
					extractError("Scan timed out after #{OPTIMEOUT} minutes", s3prefix)
					throw :next
				rescue Exception => err
					extractError(err.to_s, s3prefix, err)
					throw :next
				end
			end # catch :next
			$log.info "------------------------"

			s3object(@outputBucket, File.join(s3prefix, "END")).write(Time.now.utc.to_s, :content_type => "text/plain")
			amiNum += 1
		end if @payload[:instances]
		
		$log.info "Scan end."
	end # def extract
	
	def done
		s3object(@outputBucket, File.join(@timeStampStr, @logTarget)).write(File.read(@logFile), :content_type => "text/plain")
		@keyFiles.each { |kf| File.delete(kf) if File.exist?(kf) }
		`rm -rf #{IMAGE_DIR}/*`
	end
	
	private
	
	def extractError(msg, s3prefix, err=nil)
		$log.error msg
		$log.error err.backtrace.join("\n") unless err.nil?
		s3object(@outputBucket, File.join(s3prefix, "ERROR")).write(msg, :content_type => "text/plain")
	end
	
	def bundleExtract(vmId, bucket, manifest, s3prefix)
		$log.info "bundleExtract called"
		localImage = getAmiBundle(vmId, bucket, manifest)
		
		diskid	  = "scsi0:0"
		hardware  = "#{diskid}.present = \"TRUE\"\n"
		hardware += "#{diskid}.filename = \"#{localImage}\"\n"

		vm = MiqVm.new(hardware)

		@categories.each do |cat|
			s3name = File.join(s3prefix, cat + ".xml")
			$log.info "Processing: " + s3name
			ts = ""
			begin
				xml = vm.extract(cat)
			rescue => err
				$log.error err.to_s
				$log.error err.backtrace.join("\n")
				next
			end
			xml.to_xml.write(ts, 4)
			s3object(@outputBucket, s3name).write(ts, :content_type => "text/xml")
		end

		vm.unmount
		`rm -rf #{IMAGE_DIR}/*`
	end
	
	def instanceExtract(instObj, s3prefix)
		$log.info "instanceExtract called"
		
		dnsName = instObj.private_ip_address
		
		#
		# Check instance state.
		#
		raise "instanceExtract: Unexpected instance termination." if instObj.status == :terminated
		
		#
		# Scan open ports to determine when instance is ready, and to determine its platform.
		#
		ost = OpenStruct.new
		ost.timeout = PORT_TIMEOUT
		ost.ipaddr	= dnsName
		open_ports = []
		SSH_RETRYS.times do |n|
			$log.info("instanceExtract: scanning ports, attempt #{n}")
			open_ports = PortScanner.scanPortArray(ost, [SSH_PORT, RDP_PORT])
			break if !open_ports.empty?
			sleep SSH_SLEEP
		end
		
		raise "instanceExtract: port scan timed out" if open_ports.empty?
		if open_ports[0] == RDP_PORT
			$log.info("instanceExtract: platform appears to be windows")
			raise "instanceExtract: skipping windows image"
		else
			$log.info("instanceExtract: platform appears to be linux")
		end
		
		keyName = instObj.key_name
		raise "instanceExtract: key pair #{keyName} required to access instance #{instObj.id}" if !(keyFile = getKeyFile(keyName))
		
		$log.info "instanceExtract: dnsName = #{dnsName}"
		$log.info "instanceExtract: keyName = #{keyName}"
		
		`echo > #{KNOWN_HOSTS}`
		user = nil
		[ "ubuntu", "root" ].each do |u|
			begin
				$log.info "instanceExtract: attempting to connect with user = #{u}"
				Net::SSH.start(dnsName, u, :keys=>[keyFile], :password => "password", :verbose=>:info) do |s|
					$log.info "instanceExtract: connected with user = #{u}"
					s.exec!(%Q/ldd --version/) do |channel, stream, data|
						$log.copy data
				    end
				end
				user = u
				break
			rescue Exception => err
				$log.info "instanceExtract: Failed to connected with user = #{u}"
				$log.info err.to_s
				next
			end
		end
		
		raise "instanceExtract: could not connect to #{dnsName}" unless user
		
		$log.info "instanceExtract: Architecture = #{instObj.architecture}"
		if instObj.architecture == :x86_64
			extractor	= EXTRACTOR64
			target		= TARGET64
		elsif instObj.architecture == :i386
			extractor	= EXTRACTOR32
			target		= TARGET32
		else
			raise "instanceExtract: unrecognized architecture = #{instObj.architecture}"
		end
		
		`echo > #{KNOWN_HOSTS}`
		$log.info "instanceExtract: SFTP to #{dnsName}"
		Net::SFTP.start(dnsName, user, :keys=>[keyFile]) do |s|
	        $log.info "instanceExtract: Copying file #{extractor} to #{target}." if $log
	        s.upload!(extractor, target)
	        $log.info "instanceExtract: Copying of #{extractor} to #{target}, complete." if $log
	    end

		`echo > #{KNOWN_HOSTS}`
		stdout = ""
		stderr = ""
		Net::SSH.start(dnsName, user, :keys=>[keyFile]) do |s|
			s.exec!("chmod 755 #{target}")

		    s.exec!(%Q/#{target} --loglevel #{@logLevelStr} #{@categories.join(" ")}/) do |channel, stream, data|
				stdout <<	data if stream == :stdout
				if stream == :stderr
					$log.copy data
					stderr << data
				end
		    end
		end

		processed = false
		category = nil
		data = ""
		stdout.each_line do |l|
			if /^----- MIQ START -----: (\w*)$/ =~ l
				raise "Unexpected #{$1} start while #{category} still active" if category
				category = $1
				next
			end
			if /^----- MIQ END -----: (\w*)$/ =~ l
				raise "Unexpected end of category #{$1} encountered" if !category
				raise "End of category #{$1} encountered while #{category} active" if category != $1
				
				s3name = File.join(s3prefix, category + ".xml")
				$log.info "Processing: " + s3name
				s3object(@outputBucket, s3name).write(data, :content_type => "text/xml")
				
				processed = true
				category = nil
				data = ""
				next
			end

			raise "No active category" if !category
			data << l
		end
		
		raise "Local extractor failed: " + stderr.tr("\n", " ") if !processed
	end
	
	def instanceLaunchExtract(ami, s3prefix)
		$log.info "instanceLaunchExtract called"
		keyName = @payload[:account_info][:launch_key_name]
		
		raise "Image #{ami.id} is not an AMI, skipping." if !(ami.id =~ /^ami-.*/)
		raise "Skipping windows image: #{ami.location}" if ami.platform && ami.platform.casecmp("windows") == 0
		
		iType = ami.architecture == :x86_64 ? "m1.large" : "m1.small"
		
		begin
			$log.info "instanceLaunchExtract: launching #{ami.location}"
			$log.info "instanceLaunchExtract: instance type: #{iType}"
			instObj	= @ec2.instances.create(:image_id => ami.id,
											:key_name => keyName,
											:instance_type => iType)
			instObj.add_tag('Name', :value => 'miq-extract')
			iid		= instObj.id
			$log.info "instanceLaunchExtract: instance ID #{iid}"

			dnsName = nil
			$log.info "instanceLaunchExtract: waiting for instance ID #{iid}"
			loop do
				sleep 8
				$log.debug "instanceLaunchExtract: Instance status = #{instObj.status}"
				raise "Unexpected instance termination." if instObj.status == :terminated
				break if (dnsName = instObj.dns_name)
			end
			instanceExtract(instObj, s3prefix)
		ensure
			begin
				instObj.terminate if instObj
			rescue Exception
				# Ignore errors, instance may be gone.
			end
		end
	end
	
	def getAmiBundle(vmId, bucket, manifest)
		localManifest	= File.join(IMAGE_DIR, manifest)
		localImage		= File.join(IMAGE_DIR, File.basename(vmId, ".manifest.xml"))
		
		$log.info "Downloading bundle: #{vmId}"
		
		cmd = "ec2-download-bundle"										+
				" -b " + bucket											+
				" -m " + manifest										+
				" -a " + @payload[:account_info][:access_key_id]		+
				" -s " + @payload[:account_info][:secret_access_key]	+
				" -d " + IMAGE_DIR										+
				" -k " + @pkFile
				
		$log.debug "getAmiBundle: running command: #{cmd}"

		cmdOut = `#{cmd} 2>&1`
		if $?.exitstatus != 0
			$log.info "Download of bundle: #{vmId} failed."
			$log.info "*** Download output start ***"
			$log.info cmdOut.chomp if cmdOut
			$log.info "*** Download output end ***"
			`rm -rf #{IMAGE_DIR}/*`
			raise "Could not download image: #{vmId}"
		end
		$log.info "Bundle download complete: #{vmId}"

		$log.info "Unbundling image: #{vmId}"
		cmdOut = `ec2-unbundle -m #{localManifest} -d #{IMAGE_DIR} -s #{IMAGE_DIR} -k #{@pkFile} 2>&1`
		if $?.exitstatus != 0
			$log.error "Unbundle of: #{vmId} failed."
			$log.error "*** Unbundle output start ***"
			$log.error cmdOut.chomp if cmdOut
			$log.error "*** Unbundle output end ***"
			`rm -rf #{IMAGE_DIR}/*`
			$log.info "Could not unbundle image: #{vmId}"
			raise "Could not unbundle image: #{vmId}"
		end
		$log.info "Unbundle complete: #{vmId}"
		
		return localImage
	end # def getAmi
	
	def getKeyFile(keyName)
		keyFile	= File.join(Dir.tmpdir, keyName + $$.to_s)
		
		if !File.exist?(keyFile)
			File.open(keyFile, "w+", 0600) { |f| f.write(@payload[:account_info][:key_pair_info][keyName]) }
			@keyFiles << keyFile
		end
		return(keyFile)
	end
	
end # class Ec2Extractor
