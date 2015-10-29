class ContainerDashboardService
  def initialize(provider_id)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.nil?
  end

  def all_data
    {
      :status    => status,
      :providers => providers
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
end
