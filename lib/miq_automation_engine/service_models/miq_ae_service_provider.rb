module MiqAeMethodService
  class MiqAeServiceProvider < MiqAeServiceModelBase
    expose :zone,                  :association => true
    expose :tenant,                :association => true
    expose :managers,              :association => true
  end
end
