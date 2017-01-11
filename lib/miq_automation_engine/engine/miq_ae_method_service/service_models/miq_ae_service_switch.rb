module MiqAeMethodService
  class MiqAeServiceSwitch < MiqAeServiceModelBase
    expose :hosts,         :association => true
    expose :guest_devices, :association => true
    expose :lans,          :association => true
  end
end
