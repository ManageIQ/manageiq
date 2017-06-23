class AddUniqueIndexesToContainersTables < ActiveRecord::Migration[5.0]
  def change
    # Just having :ems_id & :ems_ref
    add_index :container_builds,         [:ems_id, :ems_ref], :unique => true
    add_index :container_build_pods,     [:ems_id, :ems_ref], :unique => true
    add_index :container_groups,         [:ems_id, :ems_ref], :unique => true
    add_index :container_limits,         [:ems_id, :ems_ref], :unique => true
    add_index :container_nodes,          [:ems_id, :ems_ref], :unique => true
    add_index :container_projects,       [:ems_id, :ems_ref], :unique => true
    add_index :container_quotas,         [:ems_id, :ems_ref], :unique => true
    add_index :container_replicators,    [:ems_id, :ems_ref], :unique => true
    add_index :container_routes,         [:ems_id, :ems_ref], :unique => true
    add_index :container_services,       [:ems_id, :ems_ref], :unique => true
    add_index :container_templates,      [:ems_id, :ems_ref], :unique => true
    add_index :persistent_volume_claims, [:ems_id, :ems_ref], :unique => true

    # Having :ems_id but not ems_ref
    add_index :container_component_statuses,
              [:ems_id, :name],
              :unique => true
    add_index :container_images,
              [:ems_id, :image_ref, :container_image_registry_id],
              :unique => true,
              :name   => "index_container_images_unique_multi_column"
    add_index :container_image_registries,
              [:ems_id, :host, :port],
              :unique => true

    # Nested tables, not having :ems_id and the foreign_key is a part of the unique index
    add_index :container_conditions,
              [:container_entity_id, :container_entity_type, :name],
              :unique => true,
              :name   => "index_container_conditions_unique_multi_column"
    add_index :security_contexts,
              [:resource_id, :resource_type],
              :unique => true,
              :name   => "index_security_contexts_unique_multi_column"
    add_index :container_env_vars,
              [:container_definition_id, :name, :value, :field_path],
              :unique => true,
              :name   => "index_container_env_vars_unique_multi_column"
    add_index :container_limit_items,
              [:container_limit_id, :resource, :item_type],
              :unique => true,
              :name   => "index_container_limit_items_unique_multi_column"
    add_index :container_port_configs,
              [:container_definition_id, :ems_ref],
              :unique => true,
              :name   => "index_container_port_configs_unique_multi_column"
    add_index :container_quota_items,
              [:container_quota_id, :resource],
              :unique => true
    add_index :container_service_port_configs,
              [:container_service_id, :ems_ref, :protocol], # FIXME(lsmola) I see duplicate ems_refs, because protocol is not part of it
              :unique => true,
              :name   => "index_container_service_port_configs_unique_multi_column"
    add_index :container_template_parameters,
              [:container_template_id, :name],
              :unique => true,
              :name   => "index_container_template_parameters_unique_multi_column"
    add_index :container_volumes,
              [:parent_id, :parent_type, :name],
              :unique => true # FIXME(lsmola) has unused :ems_ref
    add_index :custom_attributes,
              [:resource_id, :resource_type, :name, :unique_name, :section, :source],
              :unique => true,
              :name   => "index_custom_attributes_parameters_unique_multi_column"

    # FIXME(lsmola) questionable, these were modeled as nested, but they have :ems_id & :ems_ref
    # Is ems_ref unique? we were saving these under container_group
    add_index :container_definitions, [:ems_id, :ems_ref], :unique => true
    # Is ems_ref unique? we were saving these under container_definition
    add_index :containers,            [:ems_id, :ems_ref], :unique => true
  end
end
