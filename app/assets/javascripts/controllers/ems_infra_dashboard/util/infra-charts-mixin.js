angular.module('miq.util').factory('infraChartsMixin', ['pfUtils', function(pfUtils) {
  'use strict';

  var dailyTimeTooltip = function (data) {
    var theMoment = moment(data[0].x);
    return _.template('<div class="tooltip-inner"><%- col1 %>  <%- col2 %></div>')({
      col1: theMoment.format('MM/DD/YYYY'),
      col2: data[0].value + ' ' + data[0].name
    });
  };

  var chartConfig = {
    cpuUsageConfig: {
      chartId: 'cpuUsageChart',
      title: __('CPU'),
      units: __('Cores'),
      usageDataName: __('Used'),
      legendLeftText: __('Last 30 Days'),
      legendRightText: '',
      numDays: 30
    },
    memoryUsageConfig: {
      chartId: 'memoryUsageChart',
      title: __('Memory'),
      units: __('GB'),
      usageDataName: __('Used'),
      legendLeftText: __('Last 30 Days'),
      legendRightText: '',
      numDays: 30
    },
  };

  var processHeatmapData = function(heatmapsStruct, data) {
    if (data) {
      var heatmapsStructData = data.map(function(d) {
        var percent = -1;
        var tooltip = __("Cluster: ") + d.node + "<br>" + __("Provider: ") + d.provider
        if (d.percent === null || d.total === null) {
          tooltip += "<br> " + __("Usage: Unknown");
        } else {
          percent = d.percent
          tooltip += "<br>" + __("Usage: ") + sprintf(__("%d%% in use of %d total"), (percent * 100).toFixed(0), d.total);
        }

        return {
          "id": d.id,
          "tooltip": tooltip,
          "value": percent
        };
      })
      heatmapsStruct.data = _.sortBy(heatmapsStructData, 'value').reverse()
    } else  {
      heatmapsStruct.data = [];
      heatmapsStruct.dataAvailable = false
    }

    return heatmapsStruct
  };

  var processUtilizationData = function(data, xDataLabel, yDataLabel) {
    if (!data) {
      return { dataAvailable: false }
    }

    data.xData.unshift(xDataLabel)
    data.yData.unshift(yDataLabel)
    return data;
  };

  return {
    dashboardHeatmapChartHeight: 90,
    nodeHeatMapUsageLegendLabels: ['< 70%', '70-80%', '80-90%', '> 90%'],
    chartConfig: chartConfig,
    processHeatmapData: processHeatmapData,
    processUtilizationData: processUtilizationData,
    dailyTimeTooltip: dailyTimeTooltip
  };
}]);
