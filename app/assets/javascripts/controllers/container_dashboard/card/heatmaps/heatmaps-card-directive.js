angular.module( 'miq.card' ).directive('heatmapsCard', function() {
  'use strict';
  return {
    restrict: 'A',
    scope: {
      title: '@',
      heatmaps: '=',
      hidetopborder: '@',
      heatmapChartHeight: '=',
      columnSizingClass: '@',
      heatMapUsageLegendLabels: '='
    },
    templateUrl: '/static/heatmaps-card.html',
    controller: ['$scope', '$rootScope',
      function($scope, $rootScope) {
        if ($scope.columnSizingClass === undefined) {
          $scope.columnSizingClass = "col-xs-8 col-sm-6 col-md-6";
        }
      }
    ]
  };
});
