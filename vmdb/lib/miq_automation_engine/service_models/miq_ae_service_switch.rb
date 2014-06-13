module MiqAeMethodService
  class MiqAeServiceSwitch < MiqAeServiceModelBase
    expose :host,          :association => true
    expose :guest_devices, :association => true
    expose :lans,          :association => true
  end
end
