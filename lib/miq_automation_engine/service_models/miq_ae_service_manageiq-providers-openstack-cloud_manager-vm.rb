module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm < MiqAeServiceVmCloud
    expose :cloud_networks, :association => true

    expose :resize,         :override_return => nil
    expose :resize_confirm, :override_return => nil
    expose :resize_revert,  :override_return => nil

    expose :validate_resize
    expose :validate_resize_confirm
    expose :validate_resize_revert

    expose :associate_floating_ip
    expose :disassociate_floating_ip

    def attach_volume(volume_id, device = nil, options = {})
      sync_or_async_ems_operation(options[:sync], "attach_volume", [volume_id, device])
    end

    def detach_volume(volume_id, options = {})
      sync_or_async_ems_operation(options[:sync], "detach_volume", [volume_id])
    end
  end
end
