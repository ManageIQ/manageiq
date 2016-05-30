miqHttpInject(angular.module('containerCompliance', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util']))
  .controller('containerComplianceController', ['$scope', 'dashboardUtilsFactory', 'chartsMixin', '$http', '$interval', "$location",
    function($scope, dashboardUtilsFactory, chartsMixin, $http, $interval, $location) {
      document.getElementById("center_div").className += " miq-body";

      // Obj-status cards init
      $scope.status = {
        title: __("Compliance Results:"),
        count: 5,
        notifications: [
          {
            "iconClass": "pficon pficon-error-circle-o",
            "count": 4,
            "href": "#"
          },
          {
            "iconClass": "pficon pficon-warning-triangle-o",
            "count": 1
          },
          {
            "iconClass": "pficon pficon-ok",
            "count": 1
          }
        ]
      };

      $scope.donutConfig = {
        'chartId': 'chartErr',
        'units': 'Farts',
        'thresholds':{'warning':'60','error':'90'}
      };

      $scope.donutData = {
        'used': '70',
        'total': '100'
      };

      $scope.donutConfig2 = {
        'chartId': 'chart',
        'units': 'Images'
      };

      $scope.donutData2 = {
        'used': '80',
        'total': '100'
      };

    }]);
