class MiddlewareTopologyController < TopologyController
  @layout = "middleware_topology"
  @service_class = MiddlewareTopologyService

  menu_section :mdl
end
