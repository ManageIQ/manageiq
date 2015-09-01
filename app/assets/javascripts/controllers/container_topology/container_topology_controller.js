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
    $rootScope.$on("render", function(ev, vertices) {
        vertices.selectAll("title").text(function(d) { return "Name: " + d.item.metadata.name + "\nType: " + d.item.kind });
        ev.preventDefault();
    })
});
