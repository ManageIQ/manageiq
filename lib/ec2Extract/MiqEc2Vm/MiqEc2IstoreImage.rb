require_relative 'MiqEc2VmBase'

class MiqEc2IstoreImage < MiqEc2VmBase
	
	BUNDLE_DIR	= "/mnt/bundle"
	IMAGE_DIR	= "/mnt/image"
	
	def initialize(ec2_obj, host_instance, ec2, iargs)
		super
		@location			= ec2_obj.location
		@bundle_bucket		= File.dirname(@location)
		@manifest			= File.basename(@location)
		@access_key_id		= @instance_args[:account_info][:access_key_id]
		@secret_access_key	= @instance_args[:account_info][:secret_access_key]
		
		@pkFile	= File.join(Dir.tmpdir, $$.to_s)
		unless File.exist?(@pkFile)
			File.open(@pkFile, "w+", 0600) { |f| f.write(@instance_args[:account_info][:private_key]) }
		end
	end
	
	def extract(cat)
		miqVm.extract(cat)
	end
	
	def unmount
		@miqVm.unmount unless @miqVm.nil?
		unMapVolumes
	end
	
	def miqVm
		return @miqVm unless @miqVm.nil?
		
		raise "#{self.class.name}.miqVm: could not map volumes" unless mapVolumes
		cfg = getCfg
		cfg.each_line { |l| $log.debug "    #{l.chomp}" } if $log.debug?
		
		return(@miqVm = MiqVm.new(cfg))
	end
	
	def getCfg
		diskid	  = "scsi0:0"
		hardware  = "#{diskid}.present = \"TRUE\"\n"
		hardware += "#{diskid}.filename = \"#{@localImage}\"\n"
		return hardware
	end
	
	def mapVolumes
		@localImage = getAmiBundle
		return true
	end
	
	def unMapVolumes
		`rm -rf #{BUNDLE_DIR}/*`
		`rm -rf #{IMAGE_DIR}/*`
		`rm -f #{@pkFile}`
	end
	
	def getAmiBundle
		localManifest	= File.join(BUNDLE_DIR, @manifest)
		localImage		= File.join(IMAGE_DIR, File.basename(@manifest, ".manifest.xml"))
		
		`mkdir -p #{BUNDLE_DIR}`
		`mkdir -p #{IMAGE_DIR}`
		
		$log.info "Downloading bundle: #{@location}"
		
		cmd = "ec2-download-bundle"			+
				" -b " + @bundle_bucket		+
				" -m " + @manifest			+
				" -a " + @access_key_id		+
				" -s " + @secret_access_key	+
				" -d " + BUNDLE_DIR			+
				" -k " + @pkFile
				
		$log.debug "getAmiBundle: running command: #{cmd}"

		cmdOut = `#{cmd} 2>&1`
		if $?.exitstatus != 0
			$log.info "Download of bundle: #{@location} failed."
			$log.info "*** Download output start ***"
			$log.info cmdOut.chomp if cmdOut
			$log.info "*** Download output end ***"
			`rm -rf #{IMAGE_DIR}/*`
			raise "Could not download image: #{@location}"
		end
		$log.info "Bundle download complete: #{@location}"

		$log.info "Unbundling image: #{@location}"
		cmdOut = `ec2-unbundle -m #{localManifest} -d #{IMAGE_DIR} -s #{BUNDLE_DIR} -k #{@pkFile} 2>&1`
		if $?.exitstatus != 0
			$log.error "Unbundle of: #{@location} failed."
			$log.error "*** Unbundle output start ***"
			$log.error cmdOut.chomp if cmdOut
			$log.error "*** Unbundle output end ***"
			`rm -rf #{IMAGE_DIR}/*`
			$log.info "Could not unbundle image: #{@location}"
			raise "Could not unbundle image: #{@location}"
		end
		$log.info "Unbundle complete: #{@location}"
		
		return localImage
	end # def getAmiBundle
	
end
