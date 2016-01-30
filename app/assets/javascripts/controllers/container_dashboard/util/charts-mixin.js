angular.module('miq.util').factory('chartsMixin', function() {
  'use strict';

  var chartConfig = {
    cpuUsageConfig: {
      chartId: 'cpuUsageChart',
      title: __('CPU'),
      units: __('Cores'),
      usageDataName: __('Used'),
      legendLeftText: __('Last 30 Days'),
      legendRightText: '',
      tooltipType: 'valuePerDay',
      numDays: 30
    },
    memoryUsageConfig: {
      chartId: 'memoryUsageChart',
      title: __('Memory'),
      units: __('GB'),
      usageDataName: __('Used'),
      legendLeftText: __('Last 30 Days'),
      legendRightText: '',
      tooltipType: 'valuePerDay',
      numDays: 30
    },
    hourlyNetworkUsageConfig: {
      chartId    : 'networkUsageCurrentChart',
      headTitle  : __('Hourly Network Utilization'),
      timeFrame  : __('Last 24 hours'),
      units      : __('KBps'),
      dataName   : __('KBps')
    },
    dailyNetworkUsageConfig: {
      chartId  : 'networkUsageDailyChart',
      headTitle: __('Network Utilization Trends'),
      timeFrame: __('Last 30 Days'),
      units    : __('KBps'),
      dataName : __('KBps'),
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
    dashboardHeatmapChartHeight:    281,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%'],
    chartConfig: chartConfig,
    processHeatmapData: processHeatmapData
  };
});
