module MiqAeMethodService
  class MiqAeServiceSecurityGroup < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :cloud_network,         :association => true
    expose :cloud_tenant,          :association => true
    expose :firewall_rules,        :association => true
    expose :vms,                   :association => true
  end
end
