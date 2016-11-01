class ContainerTopologyController < TopologyController
  @layout = "container_topology"
  @service_class = ContainerTopologyService

  menu_section :cnt
end
