module MiqAeMethodService
  class MiqAeServiceLan < MiqAeServiceModelBase
    expose :switch,        :association => true
    expose :guest_devices, :association => true
    expose :vms,           :association => true
    expose :templates,     :association => true, :method => :miq_templates
    expose :hosts,         :association => true
  end
end
