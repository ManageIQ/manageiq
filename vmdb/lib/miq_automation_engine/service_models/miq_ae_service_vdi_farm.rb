module MiqAeMethodService
  class MiqAeServiceVdiFarm < MiqAeServiceModelBase
    expose :vdi_desktop_pools,     :association => true
    expose :active_proxy,          :association => true
    expose :version_major_minor
  end
end
