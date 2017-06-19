class ManagerRefresh::InventoryCollectionDefault::ContainerManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def container_projects(extra_attributes = {})
      attributes = {
        :model_class    => ContainerProject,
        :association    => :container_projects,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_quotas(extra_attributes = {})
      attributes = {
        :model_class    => ContainerQuota,
        :association    => :container_quotas,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_quota_items(extra_attributes = {})
      attributes = {
        :model_class => ContainerQuotaItem,
        :association => :container_quota_items,
        :manager_ref => [:container_quota, :resource],
      }

      attributes.merge!(extra_attributes)
    end

    def container_limits(extra_attributes = {})
      attributes = {
        :model_class    => ContainerLimit,
        :association    => :container_limits,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_limit_items(extra_attributes = {})
      attributes = {
        :model_class => ContainerLimitItem,
        :association => :container_limit_items,
        :manager_ref => [:container_quota, :resource, :item_type],
      }

      attributes.merge!(extra_attributes)
    end

    def container_nodes(extra_attributes = {})
      attributes = {
        :model_class    => ContainerNode,
        :association    => :container_nodes,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    # TODO: computer_systems
    # TODO: computer_system_hardwares
    # TODO: computer_system_operating_systems

    def container_image_registries(extra_attributes = {})
      attributes = {
        :model_class    => ContainerImageRegistry,
        :association    => :container_image_registries,
        :manager_ref    => [:host, :port],
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_images(extra_attributes = {})
      attributes = {
        :model_class    => ContainerImage,
        :association    => :container_images,
        :manager_ref    => [:image_ref, :container_image_registry],
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_groups(extra_attributes = {})
      attributes = {
        :model_class    => ContainerGroup,
        :association    => :container_groups,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_definitions(extra_attributes = {})
      attributes = {
        :model_class    => ContainerDefinition,
        :association    => :container_definitions,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_volumes(extra_attributes = {})
      attributes = {
        :model_class => ContainerVolume,
        :association => :container_volumes,
        :manager_ref => [:parent, :name],
      }

      attributes.merge!(extra_attributes)
    end

    def containers(extra_attributes = {})
      attributes = {
        :model_class    => Container,
        :association    => :containers,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_port_configs(extra_attributes = {})
      attributes = {
        :model_class => ContainerPortConfig,
        :association => :container_port_configs,
      }

      attributes.merge!(extra_attributes)
    end

    def container_env_vars(extra_attributes = {})
      attributes = {
        :model_class => ContainerEnvVar,
        :association => :container_env_vars,
        :manager_ref => [:container_definition, :name],
      }

      attributes.merge!(extra_attributes)
    end

    def security_contexts(extra_attributes = {})
      attributes = {
        :model_class => SecurityContext,
        :association => :security_contexts,
        :manager_ref => [:resource],
      }

      attributes.merge!(extra_attributes)
    end

    def container_replicators(extra_attributes = {})
      attributes = {
        :model_class    => ContainerReplicator,
        :association    => :container_replicators,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_services(extra_attributes = {})
      attributes = {
        :model_class    => ContainerService,
        :association    => :container_services,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_service_port_configs(extra_attributes = {})
      attributes = {
        :model_class => ContainerServicePortConfig,
        :association => :container_service_port_configs,
      }

      attributes.merge!(extra_attributes)
    end

    def container_routes(extra_attributes = {})
      attributes = {
        :model_class    => ContainerRoute,
        :association    => :container_routes,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_component_statuses(extra_attributes = {})
      attributes = {
        :model_class    => ContainerComponentStatus,
        :association    => :container_component_statuses,
        :manager_ref    => [:name],
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_templates(extra_attributes = {})
      attributes = {
        :model_class    => ContainerTemplate,
        :association    => :container_templates,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_template_parameters(extra_attributes = {})
      attributes = {
        :model_class => ContainerTemplateParameter,
        :association => :container_template_parameters,
        :manager_ref => [:container_template, :name],
      }

      attributes.merge!(extra_attributes)
    end

    def container_builds(extra_attributes = {})
      attributes = {
        :model_class    => ContainerBuild,
        :association    => :container_builds,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def container_build_pods(extra_attributes = {})
      attributes = {
        :model_class    => ContainerBuildPod,
        :association    => :container_build_pods,
        :manager_ref    => [:namespace, :name],
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def persistent_volumes(extra_attributes = {})
      attributes = {
        :model_class    => PersistentVolume,
        :association    => :persistent_volumes,
        :builder_params => {
          :parent => ->(persister) { persister.manager },
        }
      }

      attributes.merge!(extra_attributes)
    end

    def persistent_volume_claims(extra_attributes = {})
      attributes = {
        :model_class    => PersistentVolumeClaim,
        :association    => :persistent_volume_claims,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        }
      }

      attributes.merge!(extra_attributes)
    end
  end
end
