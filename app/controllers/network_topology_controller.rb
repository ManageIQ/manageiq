class NetworkTopologyController < TopologyController
  @layout = "network_topology"
  @service_class = NetworkTopologyService

  menu_section :net
end
