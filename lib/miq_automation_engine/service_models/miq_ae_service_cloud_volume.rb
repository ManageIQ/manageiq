module MiqAeMethodService
  class MiqAeServiceCloudVolume < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_ems_operations_mixin"
    include MiqAeServiceEmsOperationsMixin

    expose :ext_management_system,  :association => true
    expose :availability_zone,      :association => true
    expose :cloud_tenant,           :association => true
    expose :base_snapshot,          :association => true
    expose :cloud_volume_backups,   :association => true
    expose :cloud_volume_snapshots, :association => true
    expose :attachments,            :association => true
    expose :attach_volume,          :override_return => nil
    expose :detach_volume,          :override_return => nil
  end
end
