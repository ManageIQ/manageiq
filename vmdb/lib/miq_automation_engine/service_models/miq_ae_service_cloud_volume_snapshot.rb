module MiqAeMethodService
  class MiqAeServiceCloudVolumeSnapshot < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_tenant,          :association => true
    expose :cloud_volume,          :association => true
    expose :based_volumes,         :association => true
  end
end
