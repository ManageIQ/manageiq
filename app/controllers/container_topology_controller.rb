class ContainerTopologyController < TopologyController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  @layout = "container_topology"
end
