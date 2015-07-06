module MiqAeMethodService
  class MiqAeServiceCloudVolume < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :availability_zone,      :association => true
    expose :cloud_tenant,           :association => true
    expose :base_snapshot,          :association => true
    expose :cloud_volume_snapshots, :association => true
    expose :attachments,            :association => true
  end
end
