class ContainerDashboardService
  include UiServiceMixin
  CPU_USAGE_PRECISION = 2 # 2 decimal points

  def initialize(provider_id, controller)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @controller = controller
  end

  def all_data
    {
      :providers_link         => get_url_to_entity(:ems_container),
      :status                 => status,
      :providers              => providers,
      :heatmaps               => heatmaps,
      :ems_utilization        => ems_utilization,
      :hourly_network_metrics => hourly_network_metrics,
      :daily_network_metrics  => daily_network_metrics,
      :daily_pod_metrics      => daily_pod_metrics,
      :daily_image_metrics    => daily_image_metrics
    }.compact
  end

  def status
    if @ems.present?
      routes_count = @ems.respond_to?(:container_routes) ? @ems.container_routes.count : 0 # ems might not have routes
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
        :count        => @ems.present? ? @ems.containers.count : Container.where.not(:ext_management_system => nil).count,
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
        :count        => @ems.present? ? @ems.container_projects.count : ContainerProject.where.not(:ext_management_system => nil).count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_project)
      },
      :pods       => {
        :count        => @ems.present? ? @ems.container_groups.count : ContainerGroup.where.not(:ext_management_system => nil).count,
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
        :count        => @ems.present? ? @ems.container_images.count : ContainerImage.where.not(:ext_management_system => nil).count,
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
    provider_classes_to_ui_types = ManageIQ::Providers::ContainerManager.subclasses.each_with_object({}) { |subclass, h|
      name = subclass.name.split('::')[2]
      h[subclass.name] = name.to_sym
    }
    providers = @ems.present? ? {@ems.type => 1} : ManageIQ::Providers::ContainerManager.group(:type).count

    result = {}
    providers.each do |provider, count|
      ui_type = provider_classes_to_ui_types[provider]
      (result[ui_type] ||= build_provider_status(ui_type))[:count] += count
    end
    result.values
  end

  def build_provider_status(provider_type)
    {
      :count     => 0,
      :iconImage => icons[provider_type][:icon]
    }
  end

  def get_url_to_entity(entity)
    if @ems.present?
      @controller.polymorphic_url(@ems, :display => entity.to_s.pluralize)
    else
      @controller.url_for(:action     => 'show_list',
                          :controller => entity)
    end
  end

  def heatmaps
    # Get latest hourly rollup for each node.
    node_ids = @ems.container_nodes if @ems.present?
    metrics = MetricRollup.latest_rollups(ContainerNode.name, node_ids)
    metrics = metrics.where('timestamp > ?', 1.day.ago.utc).includes(:resource)
    metrics = metrics.includes(:resource => [:ext_management_system]) unless @ems.present?

    node_cpu_usage = []
    node_memory_usage = []

    metrics.each do |m|
      next if m.resource.nil? # Metrics are purged asynchronously and might be missing their node
      provider_name = @ems.present? ? @ems.name : m.resource.ext_management_system.name

      node_cpu_usage << {
        :id       => m.resource.id,
        :node     => m.resource.name,
        :provider => provider_name,
        :total    => m.derived_vm_numvcpus.present? ? m.derived_vm_numvcpus.round : nil,
        :percent  => m.cpu_usage_rate_average.present? ? (m.cpu_usage_rate_average / 100.0).round(CPU_USAGE_PRECISION) : nil # pf accepts fractions 90% = 0.90
      }

      node_memory_usage << {
        :id       => m.resource.id,
        :node     => m.resource.name,
        :provider => m.resource.ext_management_system.name,
        :total    => m.derived_memory_available.present? ? m.derived_memory_available.round : nil,
        :percent  => m.mem_usage_absolute_average.present? ? (m.mem_usage_absolute_average / 100.0).round(CPU_USAGE_PRECISION) : nil # pf accepts fractions 90% = 0.90
      }
    end

    {
      :nodeCpuUsage    => node_cpu_usage.presence,
      :nodeMemoryUsage => node_memory_usage.presence
    }
  end

  def ems_utilization
    used_cpu = Hash.new(0)
    used_mem = Hash.new(0)
    total_cpu = Hash.new(0)
    total_mem = Hash.new(0)

    daily_provider_metrics.each do |metric|
      date = metric.timestamp.strftime("%Y-%m-%d")
      used_cpu[date] += metric.v_derived_cpu_total_cores_used if metric.v_derived_cpu_total_cores_used.present?
      used_mem[date] += metric.derived_memory_used if metric.derived_memory_used.present?
      total_cpu[date] += metric.derived_vm_numvcpus if metric.derived_vm_numvcpus.present?
      total_mem[date] += metric.derived_memory_available if metric.derived_memory_available.present?
    end

    if used_cpu.any?
      {
        :cpu => {
          :used  => used_cpu.values.last.round,
          :total => total_cpu.values.last.round,
          :xData => used_cpu.keys,
          :yData => used_cpu.values.map(&:round)
        },
        :mem => {
          :used  => (used_mem.values.last / 1024.0).round,
          :total => (total_mem.values.last / 1024.0).round,
          :xData => used_mem.keys,
          :yData => used_mem.values.map { |m| (m / 1024.0).round }
        }
      }
    else
      {
        :cpu => nil,
        :mem => nil
      }
    end
  end

  def hourly_network_metrics
    hourly_network_trend = Hash.new(0)
    MetricRollup.with_interval_and_time_range("hourly", (1.day.ago.beginning_of_hour.utc)..(Time.now.utc))
                .where(:resource => (@ems || ManageIQ::Providers::ContainerManager.all)).each do |m|
      hour = m.timestamp.beginning_of_hour.utc
      hourly_network_trend[hour] += m.net_usage_rate_average if m.net_usage_rate_average.present?
    end

    if hourly_network_trend.any?
      {
        :xData => hourly_network_trend.keys,
        :yData => hourly_network_trend.values.map(&:round)
      }
    end
  end

  def daily_network_metrics
    daily_network_metrics = Hash.new(0)
    daily_provider_metrics.each do |m|
      day = m.timestamp.strftime("%Y-%m-%d")
      daily_network_metrics[day] += m.net_usage_rate_average if m.net_usage_rate_average.present?
    end

    if daily_network_metrics.any?
      {
        :xData => daily_network_metrics.keys,
        :yData => daily_network_metrics.values.map(&:round)
      }
    end
  end

  def fill_daily_pod_metrics(metrics, pod_create_trend, pod_delete_trend)
    metrics.each do |m|
      timestamp = m.timestamp.strftime("%Y-%m-%d")

      pod_create_trend[timestamp] += m.stat_container_group_create_rate if m.stat_container_group_create_rate.present?
      pod_delete_trend[timestamp] += m.stat_container_group_delete_rate if m.stat_container_group_delete_rate.present?
    end
  end

  def daily_pod_metrics
    daily_pod_create_trend = Hash.new(0)
    daily_pod_delete_trend = Hash.new(0)

    fill_daily_pod_metrics(daily_provider_metrics,
                           daily_pod_create_trend, daily_pod_delete_trend)

    if daily_pod_create_trend.any?
      {
        :xData    => daily_pod_create_trend.keys,
        :yCreated => daily_pod_create_trend.values.map(&:round),
        :yDeleted => daily_pod_delete_trend.values.map(&:round)
      }
    end
  end

  def daily_image_metrics
    daily_image_metrics = Hash.new(0)
    daily_provider_metrics.each do |m|
      day = m.timestamp.strftime("%Y-%m-%d")
      daily_image_metrics[day] +=
        m.stat_container_image_registration_rate if m.stat_container_image_registration_rate.present?
    end

    if daily_image_metrics.any?
      {
        :xData => daily_image_metrics.keys,
        :yData => daily_image_metrics.values.map(&:round)
      }
    end
  end

  def daily_provider_metrics
    current_user = @controller.current_user
    tp = TimeProfile.profile_for_user_tz(current_user.id, current_user.get_timezone) || TimeProfile.default_time_profile

    @daily_metrics ||= Metric::Helper.find_for_interval_name('daily', tp)
                                     .where(:resource => (@ems || ManageIQ::Providers::ContainerManager.all))
                                     .where('timestamp > ?', 30.days.ago.utc).order('timestamp')
  end
end
