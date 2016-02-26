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
      .on('click' , function() {callback(data);});
  };

  this.searchNode = function(svg, query) {
    var nodes = svg.selectAll("g");
    if (query != "") {
      var selected = nodes.filter(function (d) {
        return d.item.name != query;
      });
      selected.style("opacity", "0.2");
      var links = svg.selectAll("line");
      links.style("opacity", "0.2");
    }
  };

  this.geturl = function(d) {
    var entity_url = "";
    var action = '/show/' + d.item.miq_id;
    switch (d.item.kind) {
      case "ContainerManager":
        entity_url = "ems_container";
        break;
      case "MiddlewareManager":
        entity_url = "ems_middleware";
        break;
      default :
        entity_url = _.snakeCase(d.item.kind);
      }

      return '/' + entity_url + action;
  };

});
