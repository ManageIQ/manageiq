$:.push("#{File.dirname(__FILE__)}/../../discovery")

require 'PortScan'
require 'net/ssh'
require 'net/sftp'
require 'miq-xml'

require_relative 'MiqEc2VmBase'

class MiqEc2IstoreInstance < MiqEc2VmBase
	
	EXTRACTOR32		= File.join(File.dirname(__FILE__), "../local-extractor/local-extractor32")
	TARGET32		= File.join("/tmp", File.basename(EXTRACTOR32))
	EXTRACTOR64		= File.join(File.dirname(__FILE__), "../local-extractor/local-extractor64")
	TARGET64		= File.join("/tmp", File.basename(EXTRACTOR64))
	KNOWN_HOSTS		= "/root/.ssh/known_hosts"
	OPTIMEOUT		= 30
	
	SSH_RETRYS		= 15
	SSH_SLEEP		= 20
	SSH_PORT		= 22
	RDP_PORT		= 3389
	PORT_TIMEOUT	= 5
	
	def initialize(ec2_obj, host_instance, ec2, iargs)
		super
		@ssh_user		= nil
		@extractor		= nil
		@key_file		= nil
		@dns_name		= nil
		@keyFiles		= []
		@extractor_id	= @host_instance.id
		@logLevelStr	= @instance_args[:log_level] || 'INFO'
		
		@target32		= "#{TARGET32}.#{@extractor_id}"
		@target64		= "#{TARGET64}.#{@extractor_id}"
	end
	
	def extract(cat)
		injectExtractor if @extractor.nil?
		instanceExtract(cat)
	end
	
	def unmount
		Net::SSH.start(@dns_name, @ssh_user, :keys=>[@key_file]) do |s|
			s.exec!("rm -f #{@extractor}")
		end
		@keyFiles.each { |kf| `rm -f #{kf}` }
	end
	
	def injectExtractor
		method_id = "#{self.class.name}.injectExtractor"
		@dns_name = @ec2_obj.private_ip_address
		
		#
		# Check instance state.
		#
		raise "#{method_id}: Unexpected instance termination." if @ec2_obj.status == :terminated
		
		#
		# Scan open ports to determine when instance is ready, and to determine its platform.
		#
		ost = OpenStruct.new
		ost.timeout = PORT_TIMEOUT
		ost.ipaddr	= @dns_name
		open_ports = []
		SSH_RETRYS.times do |n|
			$log.info("#{method_id}: scanning ports, attempt #{n}")
			open_ports = PortScanner.scanPortArray(ost, [SSH_PORT, RDP_PORT])
			break if !open_ports.empty?
			sleep SSH_SLEEP
		end
		
		raise "#{method_id}: port scan timed out" if open_ports.empty?
		if open_ports[0] == RDP_PORT
			$log.info("#{method_id}: platform appears to be windows")
			raise "#{method_id}: skipping windows image"
		else
			$log.info("#{method_id}: platform appears to be linux")
		end
		
		keyName = @ec2_obj.key_name
		raise "#{method_id}: key pair #{keyName} required to access instance #{@ec2_obj.id}" if !(@key_file = getKeyFile(keyName))
		
		$log.info "#{method_id}: dnsName = #{@dns_name}"
		$log.info "#{method_id}: keyName = #{keyName}"
		
		`echo > #{KNOWN_HOSTS}`
		@ssh_user = nil
		[ "ubuntu", "root" ].each do |u|
			begin
				$log.info "#{method_id}: attempting to connect with user = #{u}"
				Net::SSH.start(@dns_name, u, :keys=>[@key_file], :password => "password") do |s|
					$log.info "#{method_id}: connected with user = #{u}"
					s.exec!(%Q/ldd --version/) do |channel, stream, data|
						$log.copy data
				    end
				end
				@ssh_user = u
				break
			rescue Exception => err
				$log.info "#{method_id}: Failed to connected with user = #{u}"
				$log.info err.to_s
				next
			end
		end
		
		raise "#{method_id}: could not connect to #{@dns_name}" unless @ssh_user
		
		$log.info "#{method_id}: Architecture = #{@ec2_obj.architecture}"
		if @ec2_obj.architecture == :x86_64
			extractor	= EXTRACTOR64
			target		= @target64
		elsif @ec2_obj.architecture == :i386
			extractor	= EXTRACTOR32
			target		= @target32
		else
			raise "#{method_id}: unrecognized architecture = #{@ec2_obj.architecture}"
		end
		
		`echo > #{KNOWN_HOSTS}`
		$log.info "#{method_id}: SFTP to #{@dns_name}"
		Net::SFTP.start(@dns_name, @ssh_user, :keys=>[@key_file]) do |s|
	        $log.info "#{method_id}: Copying file #{extractor} to #{target}." if $log
	        s.upload!(extractor, target)
	        $log.info "#{method_id}: Copying of #{extractor} to #{target}, complete." if $log
	    end
		@extractor = target
	end
	
	def instanceExtract(cat)
		`echo > #{KNOWN_HOSTS}`
		stdout = ""
		stderr = ""
		Net::SSH.start(@dns_name, @ssh_user, :keys=>[@key_file]) do |s|
			s.exec!("chmod 755 #{@extractor}")

			eid = (@extractor_id.nil? ? "" : "--extractor-id #{@extractor_id}")
			cmd = %Q/#{@extractor} #{eid} --loglevel #{@logLevelStr} #{cat}/
			$log.debug "Running: #{cmd}"
			
		    s.exec!(cmd) do |channel, stream, data|
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
				return MiqXml.load(data)
			end

			raise "No active category" if !category
			data << l
		end
		
		raise "Local extractor failed: " + stderr.tr("\n", " ") if !processed
	end
	
	def getKeyFile(keyName)
		keyFile	= File.join(Dir.tmpdir, keyName + $$.to_s)
		
		unless File.exist?(keyFile)
			File.open(keyFile, "w+", 0600) { |f| f.write(@instance_args[:account_info][:key_pair_info][keyName]) }
			@keyFiles << keyFile
		end
		return(keyFile)
	end
	
end
