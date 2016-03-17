miqHttpInject(angular.module('mwTopologyApp', ['kubernetesUI', 'ui.bootstrap', 'ManageIQ']))
    .controller('middlewareTopologyController', MiddlewareTopologyCtrl);

MiddlewareTopologyCtrl.$inject = ['$scope', '$http', '$interval', "$location", 'topologyService'];

function MiddlewareTopologyCtrl($scope, $http, $interval, $location, topologyService) {
    var self = this;
    $scope.vs = null;
    var d3 = window.d3;

    $scope.refresh = function() {
        var id;
        if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
            id = '';
        }
        else {
            id = '/'+ (/middleware_topology\/show\/(\d+)/.exec($location.absUrl())[1]);
        }
        var currentSelectedKinds = $scope.kinds;
        var url = '/middleware_topology/data'+id;
        $http.get(url).success(function(data) {
            $scope.items = data.data.items;
            $scope.relations = data.data.relations;
            $scope.kinds = data.data.kinds;
            if (currentSelectedKinds && (Object.keys(currentSelectedKinds).length !=  Object.keys($scope.kinds).length)) {
                $scope.kinds = currentSelectedKinds;
            }
        });

    };

    $scope.checkboxModel = {
        value : false
    };
    $scope.legendTooltip = "Click here to show/hide entities of this type";

    $scope.show_hide_names = function() {
       var vertices = $scope.vs;

       if($scope.checkboxModel.value) {
            vertices.selectAll("text")
               .style("display", "block");
       }
       else {
           vertices.selectAll("text")
              .style("display", "none");
       }
    };

    $scope.refresh();
    var promise = $interval( $scope.refresh, 1000*60*3);

    $scope.$on('$destroy', function() {
        $interval.cancel(promise);
    });

    $scope.$on("render", function(ev, vertices, added) {
        /*
         * We are passed two selections of <g> elements:
         * vertices: All the elements
         * added: Just the ones that were added
         */
        added.attr("class", function(d) { return d.item.kind; });
        added.append("circle")
            .attr("r", function(d) { return getDimensions(d).r})
            .attr('class' , function(d) {
              return topologyService.getItemStatusClass(d);
            });
        added.append("title");
        added.on("dblclick", function(d) {
            return self.dblclick(d);});
        added.append("image")
            .attr("xlink:href",function(d) {
                return "/assets/100/" + class_name(d) + ".png";
            })
            .attr("y", function(d) { return getDimensions(d).y})
            .attr("x", function(d) { return getDimensions(d).x})
            .attr("height", function(d) { return getDimensions(d).height})
            .attr("width", function(d) { return getDimensions(d).width});
        added.append("text")
            .attr("x", 26)
            .attr("y", 24)
            .text(function(d) { return d.item.name }).style("font-size", function(d) {return "12px"}).style("fill", function(d) {return "black"})
            .style("display", function(d) {if ($scope.checkboxModel.value) {return "block"} else {return "none"}});

        added.selectAll("title").text(function(d) {
            return topologyService.tooltip(d).join("\n");
        });
        $scope.vs = vertices;

        /* Don't do default rendering */
        ev.preventDefault();
    });

    function class_name(d) {
        var class_name = "";
        switch (d.item.kind) {
            case "MiddlewareDeployment":
                class_name = "middleware_deployment";
                break;
            case "MiddlewareServer":
                class_name = "middleware_server";
                break;
            case "MiddlewareManager":
                class_name = "vendor-hawkular";
                break;
        }
        return class_name;
    }

    this.dblclick = function dblclick(d) {
      window.location.assign(topologyService.geturl(d));
    };

    function getDimensions(d) {
        switch (d.item.kind) {
            case "MiddlewareManager":
                return { x: -20, y: -20, height: 40, width: 40, r: 28};
            case "Container" :
                return { x: -7, y: -7,height: 14, width: 14, r: 13};
            case "MiddlewareServer" :
                return { x: -12, y: -12, height: 23, width: 23, r: 19};
            default :
                return { x: -9, y: -9, height: 18, width: 18, r: 17};
        }

    }

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
