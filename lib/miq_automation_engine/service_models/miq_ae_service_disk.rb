module MiqAeMethodService
  class MiqAeServiceDisk < MiqAeServiceModelBase
    expose :hardware, :association => true
    expose :storage,  :association => true
    expose :backing,  :association => true
  end
end
