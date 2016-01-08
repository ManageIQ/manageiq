angular.module('topologyApp', ['kubernetesUI', 'ui.bootstrap'])
.config(['$httpProvider', function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
}])
.controller('containerTopologyController', ['$scope', '$http', '$interval', "$location", function($scope, $http, $interval, $location) {
  $scope.vs = null;

  $scope.refresh = function() {
    var id;
    if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
      id = '';
    } else {
      id = '/'+ (/container_topology\/show\/(\d+)/.exec($location.absUrl())[1]);
    }

    var currentSelectedKinds = $scope.kinds;
    var url = '/container_topology/data'+id;

    $http.get(url).success(function(data) {
      $scope.items = data.data.items;
      $scope.relations = data.data.relations;
      $scope.kinds = data.data.kinds;

      if (currentSelectedKinds && (Object.keys(currentSelectedKinds).length != Object.keys($scope.kinds).length)) {
        $scope.kinds = currentSelectedKinds;
      }
    });
  };

  $scope.checkboxModel = {
    value: false
  };
  $scope.legendTooltip = "Click here to show/hide entities of this type";

  $scope.show_hide_names = function() {
     var vertices = $scope.vs;

     if ($scope.checkboxModel.value) {
       vertices.selectAll("text.attached-label")
         .style("display", "block");
     } else {
       vertices.selectAll("text.attached-label")
         .style("display", "none");
     }
  };

  $scope.refresh();
  var promise = $interval($scope.refresh, 1000 * 60 * 3);

  $scope.$on('$destroy', function() {
    $interval.cancel(promise);
  });

  $scope.$on("render", function(ev, vertices, added) {
    /*
     * We are passed two selections of <g> elements:
     * vertices: All the elements
     * added: Just the ones that were added
     */

    added.attr("class", function(d) {
      return d.item.kind;
    });

    added.append("circle")
      .attr("r", function(d) {
        return getDimensions(d).r;
      })
      .style("stroke", function(d) {
        switch (d.item.status) {
          case "OK":
          case "On":
          case "Ready":
          case "Running":
          case "Succeeded":
          case "Valid":
            return "#3F9C35";
          case "NotReady":
          case "Failed":
          case "Error":
          case "Unreachable":
            return "#CC0000";
          case 'Warning':
          case 'Waiting':
          case 'Pending':
            return "#EC7A08";
          case 'Unknown':
          case 'Terminated':
            return "#bbb";
        }
      });

    added.append("title");

    added.on("dblclick", function(d) {
      return dblclick(d);
    });

    added.append("image")
      .attr("xlink:href", function(d) {
        return d.item.icon;
      })
      .attr("y", function(d) {
        return getDimensions(d).y;
      })
      .attr("x", function(d) {
        return getDimensions(d).x;
      })
      .attr("height", function(d) {
        return getDimensions(d).height;
      })
      .attr("width", function(d) {
        return getDimensions(d).width;
      });

    added.append("text")
      .attr("x", 26)
      .attr("y", 24)
      .text(function(d) {
        return d.item.name;
      })
      .attr('class', 'attached-label')
      .style("display", function(d) {
        if ($scope.checkboxModel.value) {
          return "block";
        } else {
          return "none";
        }
      });

    added.selectAll("title").text(function(d) {
      var status = [
        "Name: " + d.item.name,
        "Type: " + d.item.display_kind,
        "Status: " + d.item.status
      ];

      if (d.item.kind == 'Host' || d.item.kind == 'VM') {
        status.push("Provider: " + d.item.provider);
      }

      return status.join("\n");
    });

    $scope.vs = vertices;

    /* Don't do default rendering */
    ev.preventDefault();
  });

  function class_name(d) {
    switch (d.item.kind) {
      case "ContainerService":
      case "ContainerRoute":
      case "ContainerNode":
      case "ContainerReplicator":
        return "container_" + d.item.display_kind.toLowerCase();

      case "Vm":
      case "Host":
      case "Container":
        return d.item.kind.toLowerCase();

      case "Pod":
        return "container_group";

      case "Kubernetes":
      case "Openshift":
      case "Atomic":
      case "OpenshiftEnterprise":
      case "AtomicEnterprise":
        return "vendor-" + _.snakeCase(d.item.kind);
    }
  }

  function dblclick(d) {
    var entity_url = "";
    var action = '/show/' + d.item.miq_id;
    switch (d.item.kind) {
      case "Kubernetes":
      case "Openshift":
      case "Atomic":
      case "OpenshiftEnterprise":
      case "AtomicEnterprise":
        entity_url = "ems_container";
        break;
      case "Container":
        entity_url = class_name(d);
        action = '/explorer';
      default :
        entity_url = class_name(d);
    }

    var url = '/' + entity_url + action;
    window.location.assign(url);
  }

  function getDimensions(d) {
    switch (d.item.kind) {
      case "Kubernetes":
      case "Openshift":
      case "Atomic":
      case "OpenshiftEnterprise":
      case "AtomicEnterprise":
        return { x: -20, y: -20, height: 40, width: 40, r: 28 };
      case "Container":
        return { x: -7, y: -7, height: 14, width: 14, r: 13 };
      case "ContainerNode":
      case "Vm":
      case "Host":
        return { x: -12, y: -12, height: 23, width: 23, r: 19 };
      default:
        return { x: -9, y: -9, height: 18, width: 18, r: 17 };
    }
  }

  var d3 = window.d3;

  function getSVG() {
    var graph = d3.select("kubernetes-topology-graph");
    var svg = graph.select('svg');
    return svg;
  }

  $scope.searchNode = function() {
    var svg = getSVG();
    var query = $scope.search.query;

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

  $scope.resetSearch = function() {
    // Display all topology nodes and links
    d3.selectAll("g, line").transition()
        .duration(2000)
        .style("opacity", 1);

    // Reset the search term in search input
    $scope.search.query = "";
  };

}]);
