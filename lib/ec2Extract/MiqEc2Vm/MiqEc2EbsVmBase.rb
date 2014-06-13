require_relative 'MiqEc2VmBase'

class MiqEc2EbsVmBase < MiqEc2VmBase
	
	def initialize(ec2_obj, host_instance, ec2, iargs)
		super
		@block_device_keys = @ec2_obj.block_device_mappings.keys.sort
		@volumes = []
		@miqVm = nil
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
		`ls -l /dev/xvd*`.each_line { |l| $log.debug "        #{l.chomp}" } if $log.debug?
		cfg = getCfg
		cfg.each_line { |l| $log.debug "    #{l.chomp}" } if $log.debug?
		
		return(@miqVm = MiqVm.new(cfg))
	end
	
	def getCfg
		diskid = 'scsi0:0'
		mapdev = '/dev/xvdf'
		hardware = ''
		@block_device_keys.each do |k|
			hardware += "#{diskid}.present = \"TRUE\"\n"
			hardware += "#{diskid}.filename = \"#{mapdev}\"\n"
			diskid.succ!
			mapdev.succ!
		end
		return hardware
	end
	
	def createVolume(snap_id)
		$log.debug "    Creating volume based on #{snap_id}"
		snap = @ec2.snapshots[snap_id]
		if snap.nil?
			$log.info "    Snapshot #{snap_id} does not exist (nil)"
			return nil
		elsif !snap.exists?
			$log.info "    Snapshot #{snap_id} does not exist (!snap.exists?)"
			return nil
		end
		volume = @ec2.volumes.create(	:snapshot_id => snap_id,
										:availability_zone => @host_instance.availability_zone)
										
		volume.add_tag('Name',			:value => 'EVM extract volume')
		volume.add_tag('Description',	:value => "EVM extract volume for image: #{@ec2_obj.id}")
		
		sleep 1 while volume.status == :creating
		$log.debug "    Volume: #{volume.id}, status = #{volume.status}"
		raise "#{self.class.name}.createVolume: unexpected volume status = #{volume.status}" unless volume.status == :available
		$log.debug "    Creating volume based on #{snap_id} DONE"
		@volumes << volume
		
		return volume
	end
	
end
