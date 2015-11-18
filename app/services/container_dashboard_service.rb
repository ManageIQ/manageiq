class ContainerDashboardService
  def initialize(provider_id)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.nil?
  end

  def all_data
    {
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
        :warningCount => 0
      },
      :containers => {
        :count        => @ems.present? ? @ems.containers.count : Container.count,
        :errorCount   => 0,
        :warningCount => 0
      },
      :registries => {
        :count        => @ems.present? ? @ems.container_image_registries.count : ContainerImageRegistry.count,
        :errorCount   => 0,
        :warningCount => 0
      },
      :projects   => {
        :count        => @ems.present? ? @ems.container_projects.count : ContainerProject.count,
        :errorCount   => 0,
        :warningCount => 0
      },
      :pods       => {
        :count        => @ems.present? ? @ems.container_groups.count : ContainerGroup.count,
        :errorCount   => 0,
        :warningCount => 0,
      },
      :services   => {
        :count        => @ems.present? ? @ems.container_services.count : ContainerService.count,
        :errorCount   => 0,
        :warningCount => 0
      },
      :images     => {
        :count        => @ems.present? ? @ems.container_images.count : ContainerImage.count,
        :errorCount   => 0,
        :warningCount => 0
      },
      :routes     => {
        :count        => routes_count,
        :errorCount   => 0,
        :warningCount => 0
      }
    }
  end

  def providers
    [
      {
        :iconClass    => "pficon pficon-openshift",
        :count        => ManageIQ::Providers::Openshift::ContainerManager.count,
        :id           => "openshift",
        :providerType => "OpenShift"
      },
      {
        :iconClass    => "pficon pficon-kubernetes",
        :count        => ManageIQ::Providers::Kubernetes::ContainerManager.count,
        :id           => "kubernetes",
        :providerType => "Kubernetes"
      }
    ]
  end

  def heatmaps
    # Get latest daily rollup for each node.
    metrics = MetricRollup.where(:resource_type => ContainerNode.name, :capture_interval_name => "daily")
    metrics = metrics.where(:resource_id => @ems.container_nodes) if @ems
    metrics = metrics.order(:resource_id, :timestamp => :desc)
    metrics = metrics.select('DISTINCT ON (metric_rollups.resource_id) metric_rollups.*')
    metrics = metrics.includes(:resource)

    {
      :nodeCpuUsage    => metrics.collect { |m|
        avg_cpu = m.cpu_usage_rate_average.round(2)
        {
          :id      => m.resource_id,
          :tooltip => "Name: #{m.resource.name} - #{avg_cpu} percent of total",
          :value   => avg_cpu / 100.0 # 1% should be 0.01
        }
      },
      :nodeMemoryUsage => metrics.collect { |m|
        avg_mem = m.mem_usage_absolute_average.round(2)
        {
          :id      => m.resource_id,
          :tooltip => "Name: #{m.resource.name} - #{avg_mem} percent of total",
          :value   => avg_mem / 100.0 # 1% should be 0.01
        }
      }
    }
  end

  def node_utilization
    total_cores = 0
    used_cores = 0
    total_mem = 0
    used_mem = 0

    cpu_graph_xdata = ['dates']
    cpu_graph_ydata = ['used']
    mem_graph_xdata = ['dates']
    mem_graph_ydata = ['used']

    metrics = MetricRollup.where(:resource_type => ContainerNode.name, :capture_interval_name => "daily")
    metrics = metrics.where(:resource_id => @ems.container_nodes) if @ems
    metrics = metrics.select("sum(derived_vm_numvcpus * cpu_usage_rate_average / 100) as used_cores,
                              sum(mem_usage_absolute_average * derived_memory_available / 100) as used_mem,
                              sum(derived_vm_numvcpus) as total_cores,
                              sum(derived_memory_available) as total_mem,
                              cast(timestamp as date) as day")
    metrics = metrics.order("day").group("day")

    if metrics.first.present? # 'any?' doesnt work here
      metrics.each do |m|
        date = m.day.strftime("%Y-%m-%d")
        cpu_graph_xdata << date
        cpu_graph_ydata << m.used_cores.ceil
        mem_graph_xdata << date
        mem_graph_ydata << (m.used_mem / 1024).ceil
      end

      total_cores = metrics.last.total_cores.ceil
      used_cores = metrics.last.used_cores.ceil
      total_mem = (metrics.last.total_mem / 1024).ceil
      used_mem = (metrics.last.used_mem  / 1024).ceil
    end

    {
      :cpu => {
        :total => total_cores,
        :used  => used_cores,
        :xData => cpu_graph_xdata,
        :yData => cpu_graph_ydata
      },
      :mem => {
        :total => total_mem,
        :used  => used_mem,
        :xData => mem_graph_xdata,
        :yData => mem_graph_ydata
      }
    }
  end
end
