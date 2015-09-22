module MiqAeMethodService
  class MiqAeServiceProvider < MiqAeServiceModelBase
    expose :zone,                  :association => true
    expose :tenant,                :association => true
  end
end
