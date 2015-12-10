class ContainerDashboardService
  def initialize(provider_id, controller)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @controller = controller
  end

  def all_data
    {
      :providers_link => get_url_to_entity(:ems_container),
      :status         => status,
      :providers      => providers
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

  private

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
end
