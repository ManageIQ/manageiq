module MiqAeMethodService
  class MiqAeServicePartition < MiqAeServiceModelBase
    expose :disk,      :association => true
    expose :hardware,  :association => true
    expose :volumes,   :association => true
  end
end
