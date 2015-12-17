class ContainerDashboardService
  def initialize(provider_id, controller)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @controller = controller
  end

  def all_data
    {
      :providers_link => get_url_to_entity(:ems_container),
      :status           => status,
      :providers        => providers,
      :heatmaps         => heatmaps,
      :node_utilization => node_utilization
    }
  end

  def status
    if @ems.present? && @ems.kind_of?(ManageIQ::Providers::Openshift::ContainerManager)
      routes_count = @ems.container_routes.count
    else
      routes_count = ContainerRoute.count
    end

    {
      :nodes      => {
        :count        => @ems.present? ? @ems.container_nodes.count : ContainerNode.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_node)
      },
      :containers => {
        :count        => @ems.present? ? @ems.containers.count : Container.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container)
      },
      :registries => {
        :count        => @ems.present? ? @ems.container_image_registries.count : ContainerImageRegistry.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_image_registry)
      },
      :projects   => {
        :count        => @ems.present? ? @ems.container_projects.count : ContainerProject.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_project)
      },
      :pods       => {
        :count        => @ems.present? ? @ems.container_groups.count : ContainerGroup.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_group)
      },
      :services   => {
        :count        => @ems.present? ? @ems.container_services.count : ContainerService.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_service)
      },
      :images     => {
        :count        => @ems.present? ? @ems.container_images.count : ContainerImage.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_image)
      },
      :routes     => {
        :count        => routes_count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_route)
      }
    }
  end

  def providers
    provider_classes_to_ui_types = {
      "ManageIQ::Providers::Openshift::ContainerManager"           => :openshift,
      "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager" => :openshift,
      "ManageIQ::Providers::Kubernetes::ContainerManager"          => :kubernetes,
      "ManageIQ::Providers::Atomic::ContainerManager"              => :atomic,
      "ManageIQ::Providers::AtomicEnterprise::ContainerManager"    => :atomic
    }

    providers = @ems.present? ? {@ems.type => 1} : ManageIQ::Providers::ContainerManager.group(:type).count

    result = {}
    providers.each do |type, count|
      ui_type = provider_classes_to_ui_types[type]
      (result[ui_type] ||= build_provider_status(ui_type))[:count] += count
    end

    result.values
  end

  def build_provider_status(ui_type)
    {
      :iconClass    => "pficon pficon-#{ui_type}",
      :id           => ui_type,
      :providerType => ui_type.capitalize,
      :count        => 0
    }
  end

  def get_url_to_entity(entity)
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

  def node_utilization
    resource_ids = @ems.present? ? [@ems.id] : ManageIQ::Providers::ContainerManager.all.pluck(:id)
    metrics = VimPerformanceDaily.find_entries({:tz => @controller.current_user.get_timezone})
    metrics = metrics.where(:resource_type => 'ExtManagementSystem', :resource_id => resource_ids)
    metrics = metrics.where("timestamp > ?", 30.days.ago)
    metrics = metrics.order("timestamp")

    used_cpu = Hash.new(0)
    used_mem = Hash.new(0)
    total_cpu = Hash.new(0)
    total_mem = Hash.new(0)

    metrics.each do |metric|
      date = metric.timestamp.strftime("%Y-%m-%d")
      used_cpu[date] += metric.v_derived_cpu_total_cores_used
      used_mem[date] += metric.derived_memory_used
      total_cpu[date] += metric.derived_vm_numvcpus
      total_mem[date] += metric.derived_memory_available
    end

    if metrics.any?
      {
        :cpu => {
          :used  => used_cpu.values.last.round,
          :total => total_cpu.values.last.round,
          :xData => ["date"] + used_cpu.keys,
          :yData => ["used"] + used_cpu.values.map(&:round)
        },
        :mem => {
          :used  => (used_mem.values.last / 1024.0).round,
          :total => (total_mem.values.last / 1024.0).round,
          :xData => ["date"] + used_mem.keys,
          :yData => ["used"] + used_mem.values.map { |m| (m / 1024.0).round }
        }
      }
    else
      {}
    end
  end
end
