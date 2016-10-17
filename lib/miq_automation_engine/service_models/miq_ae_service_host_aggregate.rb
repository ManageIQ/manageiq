module MiqAeMethodService
  class MiqAeServiceHostAggregate < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :hosts,                 :association => true
  end
end
