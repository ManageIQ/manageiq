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

  var processHeatmapData = function(data) {
    if (data) {
      data = _.sortBy(data, 'value');

      return data.map(function(d) {
        var percent = d.value * 100;
        var used = Math.floor(d.value * d.info.total);
        var available = d.info.total - used;
        var tooltip = d.info.node + " : " + d.info.provider + "<br>" + percent + "%: " + used + " used of " +
          d.info.total + " total <br> " + available + " Available";

        return {
          "id": d.id,
          "tooltip": tooltip,
          "value": d.value
        };
      }).reverse()
    }
  };

  return {
    dashboardHeatmapChartHeight:    286,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%'],
    chartConfig: chartConfig,
    processHeatmapData: processHeatmapData
  };
});
