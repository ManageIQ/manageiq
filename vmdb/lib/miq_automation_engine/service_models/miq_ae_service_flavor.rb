module MiqAeMethodService
  class MiqAeServiceFlavor < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :vms,                   :association => true
  end
end
