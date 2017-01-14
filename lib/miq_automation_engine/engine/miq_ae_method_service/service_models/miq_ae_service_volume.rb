module MiqAeMethodService
  class MiqAeServiceVolume < MiqAeServiceModelBase
    expose :hardware,     :association => true
    expose :partitions,   :association => true
  end
end
