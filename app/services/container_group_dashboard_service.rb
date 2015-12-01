class ContainerGroupDashboardService
  include DashboardServicesCommonMixin

  def initialize(id, controller)
    @id = id
    @controller = controller
    @record = ContainerGroup.find(@id)
  end

  def all_data
    {
      :status => obj_statuses([:container_services, :containers])
    }
  end
end
