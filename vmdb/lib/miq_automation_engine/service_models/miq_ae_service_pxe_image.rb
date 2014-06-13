module MiqAeMethodService
  class MiqAeServicePxeImage < MiqAeServiceModelBase
    expose :pxe_server,              :association => true
    expose :customization_templates, :association => true
  end
end
