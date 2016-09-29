module MiqAeMethodService
  class MiqAeServiceHostAggregate < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :hosts,                 :association => true

    expose :update_aggregate
    expose :delete_aggregate
    expose :add_host
    expose :remove_host
  end
end
