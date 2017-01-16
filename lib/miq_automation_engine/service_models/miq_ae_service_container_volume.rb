module MiqAeMethodService
  class MiqAeServiceContainerVolume < MiqAeServiceModelBase
    expose :parent,                   :association => true
    expose :persistent_volume_claim,  :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
