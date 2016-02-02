angular.module('miq.util').factory('chartsMixin', function() {
  'use strict';

  var hourlyTimeTooltip = function(d) {
    var theMoment = moment(d[0].x);
    return _.template('<table class="c3-tooltip">' +
    '  <tbody>' +
    '    <td class="value"><%- col1 %></td>' +
    '    <td class="value text-nowrap"><%- col2 %></td>' +
    '  </tbody>' +
    '</table>')({col1: theMoment.format('h:mm A'), col2: d[0].value + ' ' + d[0].name});
  };

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
      dataName   : __('KBps'),
      tooltipFn  : hourlyTimeTooltip
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

  var processHeatmapData = function(heatmapsStruct, data) {
    if (data) {
      heatmapsStruct.data = _.sortBy(data, 'value').map(function(d) {
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
    } else  {
      heatmapsStruct.dataAvailable = false
    }

    return heatmapsStruct
  };

  var processUtilizationData = function(data, xDataLabel, yDataLabel) {
    if (data) {
      data.xData.unshift(xDataLabel)
      data.yData.unshift(yDataLabel)
      return data;
    } else {
      return { dataAvailable: false }
    }
  };

  return {
    dashboardHeatmapChartHeight:    281,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%'],
    chartConfig: chartConfig,
    processHeatmapData: processHeatmapData,
    processUtilizationData: processUtilizationData
  };
});
