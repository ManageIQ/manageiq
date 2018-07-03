module ManagerRefresh::Inventory::MiddlewareManager
  extend ActiveSupport::Concern
  include ::ManagerRefresh::Inventory::Core # if full name is not specified, Travis raises errors.

  COMMON_ATTRIBUTES = %i(name ems_ref nativeid properties feed).freeze

  class_methods do
    # rubocop:disable Naming/PredicateName
    def has_middleware_manager_domains(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareDomain,
        :association                 => :middleware_domains,
        :inventory_object_attributes => %i(type_path).concat(COMMON_ATTRIBUTES),
        :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
      }.merge(options))
    end

    def has_middleware_manager_server_groups(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareServerGroup,
        :association                 => :middleware_server_groups,
        :inventory_object_attributes => %i(type_path profile middleware_domain).concat(COMMON_ATTRIBUTES)
      }.merge(options))
    end

    def has_middleware_manager_servers(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareServer,
        :association                 => :middleware_servers,
        :inventory_object_attributes => %i(type type_path hostname product lives_on_id lives_on_type
                                           middleware_server_group).concat(COMMON_ATTRIBUTES),
        :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
      }.merge(options))
    end

    def has_middleware_manager_deployments(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareDeployment,
        :association                 => :middleware_deployments,
        :inventory_object_attributes => %i(middleware_server middleware_server_group status).concat(COMMON_ATTRIBUTES),
        :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
      }.merge(options))
    end

    def has_middleware_manager_datasources(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareDatasource,
        :association                 => :middleware_datasources,
        :inventory_object_attributes => %i(middleware_server).concat(COMMON_ATTRIBUTES),
        :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
      }.merge(options))
    end

    def has_middleware_manager_messagings(options = {})
      has_inventory({
        :model_class                 => provider_module::MiddlewareManager::MiddlewareMessaging,
        :association                 => :middleware_messagings,
        :inventory_object_attributes => %i(middleware_server messaging_type).concat(COMMON_ATTRIBUTES),
        :builder_params              => { :ext_management_system => ->(persister) { persister.manager } }
      }.merge(options))
    end
    # rubocop:enable Naming/PredicateName
  end
end
