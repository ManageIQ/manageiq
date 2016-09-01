class ContainerTopologyController < TopologyController
  include TopologyMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  private

  @layout = "container_topology"
end
