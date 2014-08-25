module MiqAeMethodService
  class MiqAeServiceFirewallRule < MiqAeServiceModelBase
    expose :resource,              :association => true
    expose :source_security_group, :association => true
  end
end
