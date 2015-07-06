module MiqAeMethodService
  class MiqAeServiceCloudSubnet < MiqAeServiceModelBase
    expose :cloud_network,     :association => true
    expose :availability_zone, :association => true
    expose :vms,               :association => true
  end
end
