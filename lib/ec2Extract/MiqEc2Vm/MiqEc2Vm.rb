require_relative 'MiqEc2EbsImage'
require_relative 'MiqEc2EbsInstance'
require_relative 'MiqEc2IstoreImage'
require_relative 'MiqEc2IstoreInstance'

class MiqEc2Vm
	
	def self.new(ec2_id, host_instance, ec2, iargs=nil)
		ec2_obj = nil
		
		if ec2_id[0,4] == "ami-"
			ec2_obj = ec2.images[ec2_id]
			raise "MiqEc2Vm.getVm: EC2 Image #{ec2_id} not found" unless ec2_obj
			return MiqEc2EbsImage.new(ec2_obj, host_instance, ec2, iargs) if ec2_obj.root_device_type == :ebs
			return MiqEc2IstoreImage.new(ec2_obj, host_instance, ec2, iargs)
		elsif ec2_id[0,2] == "i-"
			ec2_obj = ec2.instances[ec2_id]
			raise "MiqEc2Vm.getVm: EC2 Instance #{ec2_id} not found" unless ec2_obj
			return MiqEc2EbsInstance.new(ec2_obj, host_instance, ec2, iargs) if ec2_obj.root_device_type == :ebs
			return MiqEc2IstoreInstance.new(ec2_obj, host_instance, ec2, iargs)
		else
			raise "MiqEc2Vm.getVm: unrecognized ec2 ID #{ec2_id}"
		end
	end
	
end
