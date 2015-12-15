class ContainerProjectDashboardService
  include DashboardServicesCommonMixin

  def initialize(id, controller)
    @id = id
    @controller = controller
    @record = ContainerProject.find(@id)
  end

  def all_data
    {
      :status => obj_statuses([:container_groups, :container_nodes, :container_routes, :container_services])
    }
  end
end
