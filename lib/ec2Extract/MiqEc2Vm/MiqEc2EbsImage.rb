require_relative 'MiqEc2EbsVmBase'

class MiqEc2EbsImage < MiqEc2EbsVmBase
	
	def initialize(ec2_obj, host_instance, ec2, iargs)
		super
	end
	
	def mapVolumes
		mapdev = '/dev/sdf'
		@block_device_keys.each do |k|
			vol = createVolume(@ec2_obj.block_device_mappings[k][:snapshot_id])
			return false if vol.nil?
			$log.debug "    Attaching volume #{vol.id} to #{mapdev}"
			attachment = vol.attach_to(@host_instance, mapdev)
			sleep 1 until attachment.exists?
			$log.debug "    attachment: #{attachment.class.name} (exists? #{attachment.exists?})"
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
		end
	end
	
end
