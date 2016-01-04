angular.module('miq.util').factory('chartsMixin', function() {
  'use strict';

  var chartConfig = {
    cpuUsageConfig: {
      chartId: 'cpuUsageChart',
      title: 'CPU',
      units: 'Cores',
      usageDataName: 'Used',
      legendLeftText: 'Last 30 Days',
      legendRightText: '',
      tooltipType: 'valuePerDay',
      numDays: 30
    },
    memoryUsageConfig: {
      chartId: 'memoryUsageChart',
      title: 'Memory',
      units: 'GB',
      usageDataName: 'Used',
      legendLeftText: 'Last 30 Days',
      legendRightText: '',
      tooltipType: 'valuePerDay',
      numDays: 30
    },
    hourlyNetworkUsageConfig: {
      chartId    : 'networkUsageCurrentChart',
      headTitle  : 'Hourly Network Utilization',
      timeFrame  : 'Last 24 hours',
      units      : 'KBps',
      dataName   : 'KBps'
    },
    dailyNetworkUsageConfig: {
      chartId  : 'networkUsageDailyChart',
      headTitle: 'Network Utilization Trends',
      timeFrame: 'Last 30 Days',
      units    : 'KBps',
      dataName: 'KBps',
      tooltipType: 'valuePerDay'
    }
  };

  return {
    dashboardHeatmapChartHeight:    286,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%'],
    chartConfig: chartConfig
  };
});
