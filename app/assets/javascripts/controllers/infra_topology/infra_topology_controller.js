/* global miqHttpInject */

miqHttpInject(angular.module('infraTopologyApp', ['kubernetesUI', 'ui.bootstrap', 'ManageIQ']))
.controller('infraTopologyController', InfraTopologyCtrl);

InfraTopologyCtrl.$inject = ['$scope', '$http', '$interval', '$location', 'topologyService'];

function InfraTopologyCtrl($scope, $http, $interval, $location, topologyService) {
  var self = this;
  $scope.vs = null;
  var icons = null;

  var d3 = window.d3;
  $scope.refresh = function() {
    var id;
    if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
      id = '';
    } else {
      id = '/' + (/infra_topology\/show\/(\d+)/.exec($location.absUrl())[1]);
    }

    var currentSelectedKinds = $scope.kinds;
    var url = '/infra_topology/data' + id;

    $http.get(url).success(function(data) {
      $scope.items = data.data.items;
      $scope.relations = data.data.relations;
      $scope.kinds = data.data.kinds;
      icons = data.data.icons;

      if (currentSelectedKinds && (Object.keys(currentSelectedKinds).length != Object.keys($scope.kinds).length)) {
        $scope.kinds = currentSelectedKinds;
      }
    });
  };

  $scope.checkboxModel = {
    value: false
  };

  $scope.legendTooltip = __("Click here to show/hide entities of this type");

  $scope.show_hide_names = function() {
     var vertices = $scope.vs;

     if ($scope.checkboxModel.value) {
       vertices.selectAll("text.attached-label")
         .classed("visible", true);
     } else {
       vertices.selectAll("text.attached-label")
         .classed("visible", false);
     }
  };

  $scope.refresh();
  var promise = $interval($scope.refresh, 1000 * 60 * 3);

  $scope.$on('$destroy', function() {
    $interval.cancel(promise);
  });

  var contextMenuShowing = false;

  d3.select("body").on('click', function() {
    if(contextMenuShowing) {
      removeContextMenu();
    }
  });

  var removeContextMenu = function() {
      d3.event.preventDefault();
      d3.select(".popup").remove();
      contextMenuShowing = false;
  };

  self.contextMenu = function contextMenu(_that, data) {
    if(contextMenuShowing) {
      removeContextMenu();
    } else {
      d3.event.preventDefault();

      var canvas = d3.select("kubernetes-topology-graph");
      var mousePosition = d3.mouse(canvas.node());

      var popup = canvas.append("div")
          .attr("class", "popup")
          .style("left", mousePosition[0] + "px")
          .style("top", mousePosition[1] + "px");
      popup.append("h5").text("Actions on " + data.item.display_kind);

      buildContextMenuOptions(popup, data);

      var canvasSize = [
        canvas.node().offsetWidth,
        canvas.node().offsetHeight
      ];

      var popupSize = [
        popup.node().offsetWidth,
        popup.node().offsetHeight
      ];

      if (popupSize[0] + mousePosition[0] > canvasSize[0]) {
        popup.style("left", "auto");
        popup.style("right", 0);
      }

      if (popupSize[1] + mousePosition[1] > canvasSize[1]) {
        popup.style("top", "auto");
        popup.style("bottom", 0);
      }
      contextMenuShowing = !contextMenuShowing;
    }
  };

  var buildContextMenuOptions = function(popup, data) {
    if (data.item.kind == "Tag") {
      return false;
    }

    topologyService.addContextMenuOption(popup, "Go to summary page", data, self.dblclick);
  };

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
      .attr('class', function(d) {
        return topologyService.getItemStatusClass(d);
      })
      .on("contextmenu", function(d) {
        self.contextMenu(this, d);
      });

    added.append("title");

    added.on("dblclick", function(d) {
      return self.dblclick(d);
    });

    added.append("image")
      .attr("xlink:href", function (d) {
        var iconInfo = self.getIcon(d);
        switch(iconInfo.type) {
          case 'image':
            return iconInfo.icon;
          case "glyph":
            return null;
        }
      })
      .attr("height", function(d) {
        var iconInfo = self.getIcon(d);
        if (iconInfo.type != 'image') {
          return 0;
        }
        return 40;
      })
      .attr("width", function(d) {
        var iconInfo = self.getIcon(d);
        if (iconInfo.type != 'image') {
          return 0;
        }
        return 40;
      })
      .attr("y", function(d) {
        return self.getDimensions(d).y;
      })
      .attr("x", function(d) {
        return self.getDimensions(d).x;
      })
      .on("contextmenu", function(d) {
        self.contextMenu(this, d);
      });

    added.append("text")
      .each(function(d) {
        var iconInfo = self.getIcon(d);
        if (iconInfo.type != 'glyph')
          return;

        $(this).text(iconInfo.icon)
          .attr("class", "glyph")
          .attr('font-family', iconInfo.fontfamily);
      })

      .attr("y", function(d) {
        return self.getDimensions(d).y;
      })
      .attr("x", function(d) {
        return self.getDimensions(d).x;
      })
      .on("contextmenu", function(d) {
        self.contextMenu(this, d);
      });

    added.append("text")
      .attr("x", 26)
      .attr("y", 24)
      .text(function(d) {
        return d.item.name;
      })
      .attr('class', function() {
         var class_name = "attached-label";
         if ($scope.checkboxModel.value) {
           return class_name + ' visible';
         } else {
           return class_name;
         }
      });

    added.selectAll("title").text(function(d) {
      return topologyService.tooltip(d).join("\n");
    });

    $scope.vs = vertices;

    /* Don't do default rendering */
    ev.preventDefault();
  });

  this.dblclick = function dblclick(d) {
    if (d.item.kind == "Tag") {
      return false;
    }
    window.location.assign(topologyService.geturl(d));
  };

  this.getIcon = function getIcon(d) {
    switch(d.item.kind) {
      case 'InfraManager':
        return icons[d.item.display_kind];
      default:
        return icons[d.item.kind];
    }
  };

  this.getDimensions = function getDimensions(d) {
    var defaultDimensions = topologyService.defaultElementDimensions();
    switch (d.item.kind) {
      case "InfraManager":
        return { x: -20, y: -20, r: 28 };
      case "EmsCluster":
        return { x: defaultDimensions.x, y: defaultDimensions.y, r: defaultDimensions.r };
      case "Host":
        return { x: defaultDimensions.x, y: defaultDimensions.y, r: defaultDimensions.r };
      case "Tag":
        return { x: defaultDimensions.x, y: defaultDimensions.y, r: 13 };
      default:
        return defaultDimensions;
    }
  };

  $scope.searchNode = function() {
    var svg = topologyService.getSVG(d3);
    var query = $scope.search.query;

   topologyService.searchNode(svg, query);
  };

  $scope.resetSearch = function() {
    topologyService.resetSearch(d3);

    // Reset the search term in search input
    $scope.search.query = "";
  };
}
