module MiqAeMethodService
  class MiqAeServiceHardware < MiqAeServiceModelBase
    expose :ipaddresses
    expose :guest_devices,    :association => true
    expose :storage_adapters, :association => true
    expose :nics,             :association => true
    expose :ports,            :association => true
    expose :vm,               :association => true
    expose :host,             :association => true

    def mac_addresses
      object_send(:nics).collect(&:address)
    end
  end
end
