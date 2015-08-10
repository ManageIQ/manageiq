module MiqAeMethodService
  class MiqAeServiceEventStream < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :ems,                   :association => true, :method => :ext_management_system
    expose :src_vm,                :association => true, :method => :src_vm_or_template
    expose :vm,                    :association => true, :method => :src_vm_or_template
    expose :src_host,              :association => true
    expose :host,                  :association => true, :method => :src_host
    expose :dest_vm,               :association => true, :method => :dest_vm_or_template
    expose :dest_host,             :association => true
    expose :service,               :association => true
  end
end
