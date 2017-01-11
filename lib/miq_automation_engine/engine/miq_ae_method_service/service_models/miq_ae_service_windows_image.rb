module MiqAeMethodService
  class MiqAeServiceWindowsImage < MiqAeServiceModelBase
    expose :pxe_server,              :association => true
    expose :customization_templates, :association => true
  end
end
