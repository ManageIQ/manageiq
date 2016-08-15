module MiqAeMethodService
  class MiqAeServiceStorageProfile < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :storages,              :association => true
    expose :vms_and_templates,     :association => true
    expose :disks,                 :association => true
  end
end
