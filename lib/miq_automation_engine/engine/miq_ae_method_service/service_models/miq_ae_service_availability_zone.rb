module MiqAeMethodService
  class MiqAeServiceAvailabilityZone < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :vms,                   :association => true
    expose :vms_and_templates,     :association => true
    expose :cloud_subnets,         :association => true
  end
end
