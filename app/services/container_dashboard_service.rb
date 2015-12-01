class ContainerDashboardService
  def initialize(provider_id, controller)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @controller = controller
  end

  def all_data
    {
      :providers_link => url_to_entity(:ems_container),
      :status         => status,
      :providers      => providers,
      :heatmaps       => heatmaps
    }
  end

  def status
    if @ems.present? && @ems.kind_of?(ManageIQ::Providers::Openshift::ContainerManager)
      routes_count = @ems.container_routes.count
    else
      routes_count = ContainerRoute.count
    end

    {
      :container_nodes            => {
        :count        => @ems.present? ? @ems.container_nodes.count : ContainerNode.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_node)
      },
      :containers                 => {
        :count        => @ems.present? ? @ems.containers.count : Container.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container)
      },
      :container_image_registries => {
        :count        => @ems.present? ? @ems.container_image_registries.count : ContainerImageRegistry.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_image_registry)
      },
      :container_projects         => {
        :count        => @ems.present? ? @ems.container_projects.count : ContainerProject.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_project)
      },
      :container_groups           => {
        :count        => @ems.present? ? @ems.container_groups.count : ContainerGroup.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_group)
      },
      :container_services         => {
        :count        => @ems.present? ? @ems.container_services.count : ContainerService.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_service)
      },
      :container_images           => {
        :count        => @ems.present? ? @ems.container_images.count : ContainerImage.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_image)
      },
      :container_routes           => {
        :count        => routes_count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => url_to_entity(:container_route)
      }
    }
  end

  def providers
    if @ems.present?
      if @ems.kind_of?(ManageIQ::Providers::Openshift::ContainerManager) ||
         @ems.kind_of?(ManageIQ::Providers::OpenshiftEnterprise::ContainerManager)
        {
          :iconClass    => "pficon pficon-openshift",
          :id           => "openshift",
          :providerType => "OpenShift"
        }
      elsif @ems.kind_of?(ManageIQ::Providers::Kubernetes::ContainerManager)
        {
          :iconClass    => "pficon pficon-kubernetes",
          :id           => "kubernetes",
          :providerType => "Kubernetes"
        }
      elsif @ems.kind_of?(ManageIQ::Providers::Atomic::ContainerManager) ||
            @ems.kind_of?(ManageIQ::Providers::AtomicEnterprise::ContainerManager)
        {
          :iconClass    => "pficon icon-atomic",
          :id           => "atomic",
          :providerType => "Atomic"
        }
      end
    else
      [
        {
          :iconClass    => "pficon pficon-openshift",
          :count        => ManageIQ::Providers::Openshift::ContainerManager.count +
                           ManageIQ::Providers::OpenshiftEnterprise::ContainerManager.count,
          :id           => "openshift",
          :providerType => "OpenShift"
        },
        {
          :iconClass    => "pficon pficon-kubernetes",
          :count        => ManageIQ::Providers::Kubernetes::ContainerManager.count,
          :id           => "kubernetes",
          :providerType => "Kubernetes"
        },
        {
          :iconClass    => "pficon icon-atomic", # Fix in the next PF release
          :count        => ManageIQ::Providers::Atomic::ContainerManager.count +
                           ManageIQ::Providers::AtomicEnterprise::ContainerManager.count,
          :id           => "atomic",
          :providerType => "Atomic"
        }
      ]
    end
  end

  private

  def url_to_entity(entity)
    if @ems.present?
      @controller.url_for(:action     => 'show',
                          :id         => @provider_id,
                          :display    => entity.to_s.pluralize,
                          :controller => :ems_container)
    else
      @controller.url_for(:action     => 'show_list',
                          :controller => entity)
    end
  end

  def heatmaps
    # Get latest hourly rollup for each node.
    node_ids = @ems.container_nodes if @ems
    metrics = MetricRollup.latest_rollups(ContainerNode.name, node_ids)

    {
      :nodeCpuUsage => metrics.collect { |m|
        avg_cpu = m.cpu_usage_rate_average.round(2)
        {
          :id      => m.resource_id,
          :tooltip => "#{m.resource.name} - #{avg_cpu}%",
          :value   => avg_cpu / 100.0 # 1% should be 0.01
        }
      },
      :nodeMemoryUsage => metrics.collect { |m|
        avg_mem = m.mem_usage_absolute_average.round(2)
        {
          :id      => m.resource_id,
          :tooltip => "#{m.resource.name} - #{avg_mem}%",
          :value   => avg_mem / 100.0 # 1% should be 0.01
        }
      }
    }
  end
end
