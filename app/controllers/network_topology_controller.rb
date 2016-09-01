class NetworkTopologyController < TopologyController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  @layout = "network_topology"
  @service_class = NetworkTopologyService
end
