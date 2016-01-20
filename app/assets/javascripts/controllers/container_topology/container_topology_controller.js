angular.module('topologyApp', ['kubernetesUI', 'ui.bootstrap'])
.config(['$httpProvider', function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
}])
.controller('containerTopologyController',ContainerTopologyCtrl);

ContainerTopologyCtrl.$inject = ['$scope', '$http', '$interval', '$location'];

function ContainerTopologyCtrl($scope, $http, $interval, $location) {
  var self = this;
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
        return self.getDimensions(d).r;
      })
      .attr('class' , function(d) {
        switch (d.item.status) {
          case "OK":
          case "On":
          case "Ready":
          case "Running":
          case "Succeeded":
          case "Valid":
            return "Success";
          case "NotReady":
          case "Failed":
          case "Error":
          case "Unreachable":
            return "Error";
          case 'Warning':
          case 'Waiting':
          case 'Pending':
            return "Warning";
          case 'Unknown':
          case 'Terminated':
            return "Unknown";
        }
      });

    added.append("title");

    added.on("dblclick", function(d) {
      return window.location.assign(self.dblclick(d));
    });

    added.append("text")
        .text(function(d) {
          return self.getIcon(d);
        })
      .attr('class', function(d) {
          switch(d.item.kind) {
            case 'ContainerManager':
              return 'icon '+ d.item.display_kind;
            default:
              return 'icon';
          }
        })
      .attr("y", function(d) {
        return self.getDimensions(d).y;
      })
      .attr("x", function(d) {
        return self.getDimensions(d).x;
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
      return self.tooltip(d).join("\n");
    });

    $scope.vs = vertices;

    /* Don't do default rendering */
    ev.preventDefault();
  });

  this.tooltip = function tooltip(d) {
    var status = [
      "Name: " + d.item.name,
      "Type: " + d.item.display_kind,
      "Status: " + d.item.status
    ];

    if (d.item.kind == 'Host' || d.item.kind == 'Vm') {
      status.push("Provider: " + d.item.provider);
    }

   return status;
  };
  
  this.dblclick = function dblclick(d) {
    var entity_url = "";
    var action = '/show/' + d.item.miq_id;
    switch (d.item.kind) {
      case "ContainerManager":
        entity_url = "ems_container";
        break;
      default :
        entity_url = _.snakeCase(d.item.kind);
    }

    return '/' + entity_url + action;
  }


  this.getIcon = function getIcon(d) {
    switch (d.item.kind) {
      case 'Container':
        return '\uF1B2'; // fa-cube
      case "ContainerNode":
        return '\uE621';  // pficon-container-node
      case "ContainerRoute":
        return '\uE625'; // pficon-route
      case "ContainerService":
        return '\uE61E'; // pficon-service
      case "Vm":
        return '\uE600'; // pficon-screen
      case "Host":
        return '\uE620'; // pficon-cluster
      case "ContainerGroup":
        return '\uF1B3'; // fa-cubes
      case "ContainerReplicator":
        return '\uE624'; // pficon-replicator
      case "ContainerManager":
        switch (d.item.display_kind) {
          case "Kubernetes":
            return '\uE627'; // pficon-kubernetes
          case "Openshift":
          case "OpenshiftEnterprise":
            return '\uE626';  // pficon-openshift
          case "Atomic":
            return '\uE62c'; // vendor-atomic
          case "AtomicEnterprise":
            return '\uE62d'; //vendor-atomic-enterprise
        }
    }
  }

  this.getDimensions = function getDimensions(d) {
    switch (d.item.kind) {
      case "ContainerManager":
        return { x: 0, y: 16, r: 28 };
      case "Container":
        return { x: 1, y: 5, r: 13 };
      case "ContainerGroup":
        return { x: 1, y: 6, r: 17 };
      case "ContainerNode":
      case "Vm":
      case "Host":
        return { x: 0, y: 9, r: 21 };
      default:
        return { x: 0, y: 9, r: 17 };
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

}
