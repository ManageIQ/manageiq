module MiqAeMethodService
  class MiqAeServicePxeImageType < MiqAeServiceModelBase
    expose :customization_templates, :association => true
    expose :pxe_images,              :association => true
    expose :windows_images,          :association => true
    expose :iso_images,              :association => true
  end
end
