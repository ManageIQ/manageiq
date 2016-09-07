module MiqAeMethodService
  class MiqAeServiceCloudVolumeBackup < MiqAeServiceModelBase
    expose :ext_management_system,  :association => true
    expose :availability_zone,      :association => true
    expose :cloud_volume,           :association => true
  end
end
