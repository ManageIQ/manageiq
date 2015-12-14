angular.module('miq.util').factory('ChartsDataMixin', [function chartDataMixinFactory () {
  'use strict';
  return {
    dashboardHeatmapChartHeight:    286,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%']
  };
}]);
