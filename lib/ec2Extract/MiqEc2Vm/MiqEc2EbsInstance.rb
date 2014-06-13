require_relative 'MiqEc2EbsVmBase'

class MiqEc2EbsInstance < MiqEc2EbsVmBase
	
	def initialize(ec2_obj, host_instance, ec2, iargs)
		super
		@snapshots = []
	end
	
	def mapVolumes
		mapdev = '/dev/sdf'
		@block_device_keys.each do |k|
			vol = createVolume(@ec2_obj.block_device_mappings[k].volume)
			return false if vol.nil?
			$log.debug "    Attaching volume #{vol.id} to #{mapdev}"
			attachment = vol.attach_to(@host_instance, mapdev)
			sleep 1 until attachment.exists?
			$log.debug "    attachment: #{attachment.class.name} (exists? #{attachment.exists?.to_s})"
			sleep 1 while attachment.status == :attaching
			$log.debug "    Attaching volume #{vol.id} attachment status: #{attachment.status}"
			mapdev.succ!
		end
		return true
	end
	
	def unMapVolumes
		while (vol = @volumes.shift)
			vol.attachments.each do |attachment|
				attachment.delete(:force => true)
			end
			sleep 1 until vol.status == :available
			vol.delete
			sleep 1 while vol.exists?
		end
		while (snap = @snapshots.shift)
			snap.delete
			sleep 1 while snap.exists?
		end
	end
	
	def createVolume(inst_volume)
		$log.debug "    Creating snapshot of instance volume #{inst_volume.id}"
		snap = inst_volume.create_snapshot("EVM extract snapshot for instance: #{@ec2_obj.id}")
		snap.add_tag('Name', :value => 'EVM extract snapshot')
		sleep 1 while snap.status == :pending
		$log.debug "    Snapshot: #{snap.id}, status = #{snap.status}"
		raise "MiqEc2EbsInstance.createVolume: unexpected snapshot status = #{snap.status}" unless snap.status == :completed
		$log.debug "    Creating snapshot of instance volume #{inst_volume.id} DONE snap_id = #{snap.id}"
		@snapshots << snap
		super(snap.id)
	end
	
end
