ManageIQ.angular.app.service('topologyService', function() {
  this.tooltip = function tooltip(d) {
    var status = [
      __("Name: ") + d.item.name,
      __("Type: ") + d.item.display_kind,
      __("Status: ") + d.item.status
    ];

    if (d.item.kind == 'Host' || d.item.kind == 'Vm') {
      status.push(__("Provider: ") + d.item.provider);
    }

    return status;
  };

  this.addContextMenuOption = function(popup, text, data, callback) {
    popup.append("p").text(text)
      .on('click', function() { callback(data); });
  };

  this.searchNode = function(svg, query) {
    var nodes = svg.selectAll("g");
    nodes.style("opacity", "1");
    if (query != "") {
      var selected = nodes.filter(function (d) {
        return d.item.name.indexOf(query) == -1;
      });
      selected.style("opacity", "0.2");
      var links = svg.selectAll("line");
      links.style("opacity", "0.2");
    }
  };

  this.resetSearch = function(d3) {
    // Display all topology nodes and links
    d3.selectAll("g, line").transition()
      .duration(2000)
      .style("opacity", 1);
  };

  this.geturl = function(d) {
    var entity_url = "";
    var action = '/';

    switch (d.item.kind) {
      case "ContainerManager":
        entity_url = "ems_container";
        break;
      case "NetworkManager":
        entity_url = "ems_network";
        break;
      case "MiddlewareManager":
        entity_url = "ems_middleware";
        break;
      case "InfraManager":
        entity_url = "ems_infra";
        break;
      case "CloudManager":
        entity_url = "ems_cloud";
        break;
      default : // for non provider entities, use the show action
        action = '/show/';
        entity_url = _.snakeCase(d.item.kind);
      }
      return '/' + entity_url + action + d.item.miq_id;
  };

  this.getSVG = function(d3) {
    var graph = d3.select("kubernetes-topology-graph");
    var svg = graph.select('svg');
    return svg;
  };

  this.defaultElementDimensions = function() {
    return { x: 0, y: 9, r: 17 };
  };

  this.getItemStatusClass = function(d) {
    switch (d.item.status) {
      case "OK":
      case "Active":
      case "Available":
      case "On":
      case "Ready":
      case "Running":
      case "Succeeded":
      case "Valid":
        return "success";
      case "NotReady":
      case "Failed":
      case "Error":
      case "Unreachable":
        return "error";
      case 'Warning':
      case 'Waiting':
      case 'Pending':
        return "warning";
      case 'Unknown':
      case 'Terminated':
        return "unknown";
    }
  };
});
