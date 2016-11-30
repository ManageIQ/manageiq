/* global miqHttpInject */

miqHttpInject(angular.module('containerLiveDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts']))
  .controller('containerLiveDashboardController', ['$scope', 'pfViewUtils', '$http', '$interval', '$timeout', '$window',
  function ($scope, pfViewUtils, $http, $interval, $timeout, $window) {
    $scope.tenant = '_ops';

    // get the pathname and remove trailing / if exist
    var pathname = $window.location.pathname.replace(/\/$/, '');
    var id = '/' + (/^\/[^\/]+\/(\d+)$/.exec(pathname)[1]);

    var initialization = function() {
      $scope.filtersText = '';
      $scope.definitions = [];
      $scope.items = [];
      $scope.tags = {};
      $scope.tagsLoaded = false;

      $scope.applied = false;
      $scope.filterChanged = true;
      $scope.viewGraph = false;
      $scope.chartData = {};

      $scope.filterConfig.fields = [];
      $scope.filterConfig.resultsCount = $scope.items.length;
      $scope.filterConfig.appliedFilters = [];
      $scope.filterConfig.onFilterChange = filterChange;

      $scope.toolbarConfig.filterConfig = $scope.filterConfig;
      $scope.toolbarConfig.actionsConfig = $scope.actionsConfig;

      $scope.url = '/container_dashboard/data' + id + '/?live=true&tenant=' + $scope.tenant;
    }

    var filterChange = function (filters) {
      $scope.filterChanged = true;
      $scope.filtersText = "";
      $scope.tags = {};
      $scope.filterConfig.appliedFilters.forEach(function (filter) {
        $scope.filtersText += filter.title + " : " + filter.value + "\n";
        $scope.tags[filter.id] = filter.value;
      });
    };

    var selectionChange = function() {
      $scope.itemSelected = false;
      for (var i = 0; i < $scope.items.length && !$scope.itemSelected; i++) {
        if ($scope.items[i].selected) {
          $scope.itemSelected = true;
        }
      }
    };

    $scope.doApply = function() {
      $scope.applied = true;
      $scope.filterChanged = false;
      $scope.refresh();
    };

    $scope.doViewGraph = function() {
      $scope.viewGraph = true;
      $scope.chartDataInit = false;
      $scope.refresh_graph_data();
    };

    $scope.doViewMetrics = function() {
      $scope.viewGraph = false;
      $scope.refresh();
    };

    var doRefreshTenant = function (action) {
      $scope.tenant = action.tenant;

      initialization();
      filterChange();
      getMetricTags();
    };

    var getMetricTags = function() {
      $http.get($scope.url + '&query=metric_tags').success(function(response) {
        $scope.tagsLoaded = true;
        if (response && angular.isArray(response.metric_tags)) {
          response.metric_tags.sort();
          for (var i = 0; i < response.metric_tags.length; i++) {
            $scope.filterConfig.fields.push(
              {
                id: response.metric_tags[i],
                title:  response.metric_tags[i],
                placeholder: sprintf(__("Filter by %s..."), response.metric_tags[i]),
                filterType: 'alpha'
              });
          }
        } else {
          // No filters available, apply without filtering
          $scope.toolbarConfig.filterConfig = undefined;
          $scope.doApply();
        }
      });
    };

    var getLatestData = function(item) {
      var params = '&query=get_data&metric_id=' + item.id + '&limit=5&order=DESC';

      $http.get($scope.url + params).success(function (response) {
        'use strict';
        if (response.error) {
          showErrorMessage(response.error);
        } else {
          var data = response.data;

          item.lastValues = {};
          angular.forEach(data, function(d) {
            item.lastValues[d.timestamp] = numeral(d.value).format('0,0.00a');
          });

          if (data.length > 0) {
            var lastValue = data[0].value;
            item.last_value = numeral(lastValue).format('0,0.00a');
            item.last_timestamp = data[0].timestamp;
          } else {
            item.last_value = '-';
            item.last_timestamp = '-';
          }

          if (data.length > 1) {
            var prevValue = data[1].value;
            if (angular.isNumber(lastValue) && angular.isNumber(prevValue)) {
              var change;
              if (prevValue !== 0 && lastValue !== 0) {
                change = Math.round((lastValue - prevValue) / lastValue);
              } else if (lastValue !== 0) {
                change = 1;
              } else {
                change = 0;
              }
              item.percent_change = "(" + numeral(change).format('0,0.00%') + ")";
            }
          }
        }
      });
    };

    $scope.refresh = function() {
      $scope.loadingMetrics = true;
      var _tags = $scope.tags != {} ? '&tags=' + JSON.stringify($scope.tags) : '';
      $http.get($scope.url + '&query=metric_definitions' + _tags).success(function (response) {
        'use strict';
        $scope.loadingMetrics = false;
        if (response.error) {
          showErrorMessage(response.error);
          return;
        }

        $scope.items = response.metric_definitions.filter(function(item) {
          return item.id && item.type;
        });

        angular.forEach($scope.items, getLatestData);

        $scope.filterConfig.resultsCount = $scope.items.length;
      });
    };

    $scope.refresh_graph = function(metric_id, n) {
      // TODO: replace with a datetimepicker, until then add 24 hours to the date
      var ends = $scope.timeFilter.date.valueOf() + 24 * 60 * 60;
      var diff = $scope.timeFilter.time_range * $scope.timeFilter.range_count * 60 * 60 * 1000; // time_range is in hours
      var starts = ends - diff;
      var bucket_duration = parseInt(diff / 1000 / 200); // bucket duration is in seconds
      var params = '&query=get_data&metric_id=' + metric_id + '&ends=' + ends +
                   '&starts=' + starts+ '&bucket_duration=' + bucket_duration + 's';

      $http.get($scope.url + params).success(function(response) {
        'use strict';
        if (response.error) {
          showErrorMessage(response.error);
          return;
        }

        var data  = response.data;
        var xData = data.map(function(d) { return d.start; });
        var yData = data.map(function(d) { return d.avg || null; });

        xData.unshift('time');
        yData.unshift(metric_id);

        // TODO: Use time buckets
        $scope.chartData.xData = xData;
        $scope.chartData['yData'+n] = yData;

        $scope.chartDataInit = true;
        $scope.loadCount++;
        if ($scope.loadCount >= $scope.selectedItems.length) {
          $scope.loadingData = false;
        }
      });
    };

    $scope.refresh_graph_data = function() {
      $scope.loadCount = 0;
      $scope.loadingData = true;
      $scope.chartData = {};

      $scope.selectedItems = $scope.items.filter(function(item) { return item.selected });

      for (var i = 0; i < $scope.selectedItems.length; i++) {
        var metric_id = $scope.selectedItems[i].id;
        $scope.refresh_graph(metric_id, i);
      }
    };

    $scope.timeRanges = [
      {title: _("Hours"), value: 1},
      {title: _("Days"), value: 24},
      {title: _("Weeks"), value: 168},
      {title: _("Months"), value: 672}
    ];

    $scope.timeFilter = {
      time_range: 24,
      range_count: 1,
      date: moment()
    };

    $scope.dateOptions = {
      format: __('MM/DD/YYYY HH:mm')
    };

    $scope.countDecrement = function() {
      if ($scope.timeFilter.range_count > 1) {
        $scope.timeFilter.range_count--;
      }
    };

    $scope.countIncrement = function() {
      $scope.timeFilter.range_count++;
    };

    // Graphs
    $scope.chartConfig = {
      legend       : { show: false },
      chartId      : 'adHocMetricsChart',
      point        : { r: 1 },
      axis         : {
        x: {
          tick: {
            count: 25,
            format: function (value) { return moment(value).format(__('MM/DD/YYYY HH:mm')); }
          }},
        y: {
          tick: {
            count: 4,
            format: function (value) { return numeral(value).format('0,0.00a'); }
          }}
      },
      setAreaChart : true,
      subchart: {
        show: true
      }
    };

    $scope.actionsConfig = {
      actionsInclude: true,
      moreActions: [
        {
          name: 'System',
          tenant: '_system',
          title: __("Use the System Tenant Metrics"),
          actionFn: doRefreshTenant
        },
        {
          name: 'Ops',
          tenant: '_ops',
          title: __("Use the Ops Tenant Metrics"),
          actionFn: doRefreshTenant
        }
      ]
    };

    $scope.graphToolbarConfig = {
      actionsConfig: $scope.actionsConfig
    };

    $scope.itemSelected = false;

    $scope.listConfig = {
      selectionMatchProp: 'id',
      showSelectBox: true,
      useExpandingRows: true,
      onCheckBoxChange: selectionChange
    };

    $scope.filterConfig = {};
    $scope.toolbarConfig = {};

    initialization();
    getMetricTags();
  }
]);
