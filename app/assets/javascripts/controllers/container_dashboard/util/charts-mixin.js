angular.module('miq.util').factory('chartsMixin', function(pfUtils) {
  'use strict';

  var hourlyTimeTooltip = function (data) {
    var theMoment = moment(data[0].x);
    return _.template('<div class="tooltip-inner"><%- col1 %>: <%- col2 %></div>')
      ({col1: theMoment.format('h:mm A'), col2: data[0].value + ' ' + data[0].name});
  };

  var dailyTimeTooltip = function (data) {
    var theMoment = moment(data[0].x);
    return _.template('<div class="tooltip-inner"><%- col1 %>  <%- col2 %></div>')({
      col1: theMoment.format('MM/DD/YYYY'),
      col2: data[0].value + ' ' + data[0].name
    });
  };

  var dailyPodTimeTooltip = function (data) {
    var theMoment = moment(data[0].x);
    return _.template('<div class="tooltip-inner"><%- col1 %></br>  <%- col2 %></div>')({
      col1: theMoment.format('MM/DD/YYYY'),
      col2: data[0].value + ' ' + data[0].name + ', ' + data[1].value + ' ' + data[1].name
    });
  };

  var lineChartTooltipPositionFactory = function(chartId) {
    var elementQuery = '#' + chartId + 'lineChart';

    return function (data, width, height, element) {
      var center;
      var top;
      var chartBox;
      var graphOffsetX;
      var x;

      try {
        center = parseInt(element.getAttribute('x'));
        top = parseInt(element.getAttribute('y'));
        chartBox = document.querySelector(elementQuery).getBoundingClientRect();
        graphOffsetX = document.querySelector(elementQuery + ' g.c3-axis-y').getBoundingClientRect().right;
        x = Math.max(0, center + graphOffsetX - chartBox.left - Math.floor(width / 2));

        return {
          top: top - height,
          left: Math.min(x, chartBox.width - width)
        };
      } catch (e) {
      }
    };
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
    dailyNetworkUsageConfig: {
      chartId  : 'networkUsageDailyChart',
      headTitle: __('Network Utilization Trend'),
      timeFrame: __('Last 30 Days'),
      units    : __('KBps'),
      dataName : __('KBps'),
      tooltipFn  : dailyTimeTooltip
    },
    dailyPodUsageConfig: {
      chartId     : 'podUsageDailyChart',
      headTitle   : __('Pod Creation and Deletion Trends'),
      createdLabel: __('Created'),
      deletedLabel: __('Deleted'),
      tooltip     : {
        contents: dailyPodTimeTooltip,
        position: lineChartTooltipPositionFactory('podUsageDailyChart'),
      },
      point       : {r: 1},
      size        : {height: 145},
      color       : {pattern: [pfUtils.colorPalette.blue, pfUtils.colorPalette.green]},
      grid        : {y: {show: false}},
      setAreaChart: true
    },
    dailyImageUsageConfig: {
      chartId     : 'imageUsageDailyChart',
      headTitle   : __('New Image Usage Trend'),
      createdLabel: __('Images'),
      tooltip     : {
        contents: dailyTimeTooltip,
        position: lineChartTooltipPositionFactory('imageUsageDailyChart'),
      },
      point       : {r: 1},
      size        : {height: 93},
      grid        : {y: {show: false}},
      setAreaChart: true
    }
  };

  var processHeatmapData = function(heatmapsStruct, data) {
    if (data) {
      var heatmapsStructData = data.map(function(d) {
        var percent = -1;
        var tooltip = __("Node: ") + d.node + "<br>" + __("Provider: ") + d.provider
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

  var processPodUtilizationData = function(data, xDataLabel, yCreatedLabel, yDeletedLabel) {
    if (data) {
      data.xData.unshift(xDataLabel);
      data.yCreated.unshift(yCreatedLabel);
      data.yDeleted.unshift(yDeletedLabel);
      return data;
    } else {
      return { dataAvailable: false }
    }
  };

  return {
    dashboardHeatmapChartHeight:    90,
    nodeHeatMapUsageLegendLabels:   ['< 70%', '70-80%' ,'80-90%', '> 90%'],
    chartConfig: chartConfig,
    processHeatmapData: processHeatmapData,
    processUtilizationData: processUtilizationData,
    processPodUtilizationData: processPodUtilizationData,
    dailyTimeTooltip: dailyTimeTooltip
  };
});
