/* global miqHttpInject */

miqHttpInject(angular.module('containerLiveDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts']))
  .controller('containerLiveDashboardController', ['$scope', 'pfViewUtils', '$location', '$http', '$interval', '$timeout', '$window',
  function ($scope, pfViewUtils, $location, $http, $interval, $timeout, $window) {
    $scope.filtersText = '';
    $scope.definitions = [];
    $scope.items = [];
    $scope.tags = {};
    $scope.tagsLoaded = false;

    $scope.applied = false;
    $scope.viewGraph = false;
    $scope.chartData = {};

    // Graphs
    var formatNumber = function (n) {
      var ranges = [
        { divider: 1e9 , suffix: 'G' },
        { divider: 1e6 , suffix: 'M' },
        { divider: 1e3 , suffix: 'k' }
      ];
      for (var i = 0; i < ranges.length; i++) {
        if (n >= ranges[i].divider) {
          return (n / ranges[i].divider).toFixed(2).toString() + ranges[i].suffix;
        }
      }
      return n.toFixed(2).toString();
    };

    $scope.chartConfig = {
      legend       : { show: false },
      chartId      : 'adHocMetricsChart',
      point        : { r: 1 },
      axis         : {
        x: {
          tick: {
            format: function (value) { return moment(value).utc().format(__('MM/DD/YYYY HH:mm')); }
          }},
        y: {
          tick: {
            count: 4,
            format: function (value) { return formatNumber(value); }
          }}
      },
      setAreaChart : true
    };

    // get the pathname and remove trailing / if exist
    var tenant = '_system';
    var pathname = $window.location.pathname.replace(/\/$/, '');
    var id = '/' + (/^\/[^\/]+\/(\d+)$/.exec(pathname)[1]);
    var url = '/container_dashboard/data' + id + '/?live=true&tenant=' + tenant;

    var filterChange = function (filters) {
      $scope.filtersText = "";
      $scope.tags = {};
      $scope.filterConfig.appliedFilters.forEach(function (filter) {
        $scope.filtersText += filter.title + " : " + filter.value + "\n";
        $scope.tags[filter.id] = filter.value;
      });
    };

    $scope.filterConfig = {
      fields: [],
      resultsCount: $scope.items.length,
      appliedFilters: [],
      onFilterChange: filterChange
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

    $scope.actionsConfig = {
      actionsInclude: true
    };

    $scope.toolbarConfig = {
      filterConfig: $scope.filterConfig,
      actionsConfig: $scope.actionsConfig
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

    var getMetricTags = function() {
      $http.get(url + '&query=metric_tags').success(function(response) {
        console.dir(response);
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

    $scope.refresh = function() {
      $scope.loadingMetrics = true;
      var _tags = $scope.tags != {} ? '&tags=' + JSON.stringify($scope.tags) : '';
      $http.get(url + '&query=metric_definitions' + _tags).success(function (response) {
        'use strict';
        $scope.loadingMetrics = false;
        if (response.error) {
          console.dir(response.error);
          $timeout($scope.refresh, 500);   // TODO: This seems a bit extreme
          return;
        }

        $scope.items = response.metric_definitions;
        $scope.filterConfig.resultsCount = $scope.items.length;
      });
    };

    $scope.refresh_graph = function(metric_id, n) {
      var ends = new Date().getTime();
      var diff = 60 * 60 * 60 * 1000;
      var starts = ends - diff;
      var bucket_duration = diff / 1000 / 30;
      var params = '&query=get_data&metric_id=' + metric_id + '&ends=' + ends + '&starts=' + starts;

      $http.get(url + params).success(function(response) {
        'use strict';
        if (response.error) {
          $timeout(function() { $scope.refresh_graph(metric_id); }, 1000);   // TODO: This seems a bit extreme
          return;
        }

        var data       = response.data;
        var xData      = data.filter(d => !d.empty).map(d => d.timestamp || d.start);
        var yData      = data.filter(d => !d.empty).map(d => d.value || d.avg || 0);

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

      $scope.selectedItems = $scope.items.filter(item => item.selected);

      for (var i = 0; i < $scope.selectedItems.length; i++) {
        var metric_id = $scope.selectedItems[i].id;
        $scope.refresh_graph(metric_id, i);
      }
    };
    
    getMetricTags();
  }
]);
