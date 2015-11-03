angular.module('miq.charts').directive('heatMapLegend',
  function() {
    'use strict';
    return {
      restrict: 'A',
      scope: {
        legend: '='
      },
      replace: true,
      templateUrl: '/static/heatmap-legend.html',
      controller: ['$scope', '$rootScope',
        function($scope, $rootScope) {
          var items = [];

          var getDefaultHeatmapColorPattern = function() {
            return ['#d4f0fa', '#F9D67A', '#EC7A08', '#CE0000'];
          };

          var legendColors = getDefaultHeatmapColorPattern();
          if ($scope.legend) {
            for (var i = $scope.legend.length - 1; i >= 0; i--) {
              items.push({
                text: $scope.legend[i],
                color: legendColors[i]
              });
            }
          }
          $scope.legendItems = items;
        }]
    };
  }
);
