angular.module('containerProjectDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.util'])
  .config(['$httpProvider', function($httpProvider) {
    $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
  }])
  .controller('containerProjectDashboardController', ['$scope','miq.util', '$http', '$interval', "$location",
    function($scope, containerDashboardUtils, $http, $interval, $location) {
      document.getElementById("center_div").className += " miq-body";

      $scope.objectStatus = containerDashboardUtils.createAllStatuses();

      $scope.refresh = function() {
        var id = '/'+ (/container_project\/show\/(\d+)/.exec($location.absUrl())[1]);
        var url = '/container_project/data'+id;

        $http.get(url).success(function(response) {
            'use strict';

            var data = response.data;

            containerDashboardUtils.updateAllStatuses($scope.objectStatus, data.status)
          });
      };

      $scope.refresh();
      var promise = $interval( $scope.refresh, 1000*60*3);

      $scope.$on('$destroy', function() { $interval.cancel(promise); });
    }]);
