angular.module('topologyApp', ['kubernetesUI'])
.config(['$httpProvider', function($httpProvider) {
    $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
}])
.controller('containerTopologyController', ['$scope', '$http', '$interval', "$location",  function($scope, $http, $interval, $location) {
    $scope.refresh = function() {
        var id;
        if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
            id = '';
        }
        else {
            id = '/'+ (/container_topology\/show\/(\d+)/.exec($location.absUrl())[1]);
        }

        var url = '/container_topology/data'+id;
        $http.get(url).success(function(data) {
            $scope.items = data.data.items;
            $scope.relations = data.data.relations;
            $scope.kinds = data.data.kinds;
        });

    };

    $scope.refresh();
    var promise = $interval( $scope.refresh, 1000*60*3);

    $scope.$on('$destroy', function() {
        $interval.cancel(promise);
    });
}])

.run(function($rootScope) {
        $rootScope.$on("render", function(ev, vertices, added) {
            /*
             * We are passed two selections of <g> elements:
             * vertices: All the elements
             * added: Just the ones that were added
             */
            added.attr("class", function(d) { return d.item.kind; });
            added.append("circle").attr("r", function(d) { return getDimensions(d).r}).style("stroke", function(d) {
                        switch (d.item.status) {
                            case "OK":
                            case "on":
                            case "Ready":
                            case "Running":
                            case "Succeeded":
                                return "#3F9C35";
                            case "NotReady":
                            case "Failed":
                                return "#CC0000";
                            case 'warning':
                            case 'Pending':
                                return "#EC7A08";
                            case 'unknown':
                                return "#bbb";
                        }});
            added.append("title");
            added.append("image")
                .attr("xlink:href",function(d) {
                    var image_url = "/images/icons/new/";
                    switch (d.item.kind) {
                        case "Service":
                        case "Node":
                        case "Replicator":
                            image_url += "container_" + d.item.kind.toLowerCase() + ".png";
                            break;
                        case "VM":
                        case "Host":
                        case "Container":
                            image_url += d.item.kind.toLowerCase() + ".png";
                            break;
                        case "Pod":
                            image_url += "container_group.png";
                            break;
                    }
                    return image_url;
                })
                .attr("y", function(d) { return getDimensions(d).y})
                .attr("x", function(d) { return getDimensions(d).x})
                .attr("height", function(d) { return getDimensions(d).height})
                .attr("width", function(d) { return getDimensions(d).width});


            vertices.selectAll("title").text(function(d) { return "Name: " + d.item.name + "\nType: " + d.item.kind + "\nStatus: " + d.item.status });
            //vertices.selectAll("use").classed("running", function(d) { return true; });

            /* Don't do default rendering */
            ev.preventDefault();
        });

        function getDimensions(d) {
            switch (d.item.kind) {
                case "Container" :
                    return { x: -7, y: -7,height: 14, width: 14, r: 13};
                case "Node" :
                case "VM" :
                case "Host" :
                    return { x: -12, y: -12, height: 23, width: 23, r: 19};
                default :
                    return { x: -9, y: -9, height: 18, width: 18, r: 17};
            }

        }


});
