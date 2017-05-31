module MiqAeMethodService
  class MiqAeServiceIsoDatastore < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :iso_images,            :association => true
  end
end
