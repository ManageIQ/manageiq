module ManageIQ::Providers
  class Hawkular::Inventory::Persister::MiddlewareManager < ManagerRefresh::Inventory::Persister
    include ManagerRefresh::Inventory::Core

    COMMON_ATTRIBUTES = %i(name ems_ref nativeid properties feed).freeze

    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareDomain,
      :association                 => :middleware_domains,
      :inventory_object_attributes => %i(type_path).concat(COMMON_ATTRIBUTES),
      :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
    )
    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareServerGroup,
      :association                 => :middleware_server_groups,
      :inventory_object_attributes => %i(type_path profile middleware_domain).concat(COMMON_ATTRIBUTES)
    )
    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareServer,
      :association                 => :middleware_servers,
      :inventory_object_attributes => %i(type_path hostname product lives_on_id lives_on_type
                                         middleware_server_group).concat(COMMON_ATTRIBUTES),
      :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
    )
    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareDeployment,
      :association                 => :middleware_deployments,
      :inventory_object_attributes => %i(middleware_server middleware_server_group status).concat(COMMON_ATTRIBUTES),
      :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
    )
    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareDatasource,
      :association                 => :middleware_datasources,
      :inventory_object_attributes => %i(middleware_server).concat(COMMON_ATTRIBUTES),
      :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
    )
    has_inventory(
      :model_class                 => provider_module::MiddlewareManager::MiddlewareMessaging,
      :association                 => :middleware_messagings,
      :inventory_object_attributes => %i(middleware_server messaging_type).concat(COMMON_ATTRIBUTES),
      :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
    )
  end
end
