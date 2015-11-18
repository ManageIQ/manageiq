angular.module('miq.util').factory('ChartsDataMixin', ['$timeout', '$q', function chartDataMixinFactory ($timeout, $q) {
  return {
    dashboardSparklineChartHeight:  64,
    dashboardHeatmapChartHeight:    "120px",
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%']
  };
}]);
