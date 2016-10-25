/* global miqHttpInject */

miqHttpInject(angular.module('containerLiveDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts']))
  .controller('containerLiveDashboardController', ['$scope', 'pfViewUtils', '$location', '$http', '$interval', '$timeout', '$window',
  function ($scope, pfViewUtils, $location, $http, $interval, $timeout, $window) {
    $scope.filtersText = '';
    $scope.items = [];
    $scope.tags = {};

    $scope.loadingDone = [];
    $scope.liveData = {};
    //$scope.liveTitle = [];
    //$scope.liveConfig = [];

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
    }

    var dailyPodTimeTooltip = function (data) {
      var theMoment = moment(data[0].x);
      return _.template('<div class="tooltip-inner"><%- col1 %> | <%- col2 %></div>')({
        col1: theMoment.utc().format('HH:mm'),
        col2: formatNumber(data[0].value)
      });
    };

    // get the pathname and remove trailing / if exist
    var tenant = '_system';
    var pathname = $window.location.pathname.replace(/\/$/, '');
    var id = '/' + (/^\/[^\/]+\/(\d+)$/.exec(pathname)[1]);
    var url = '/container_dashboard/data' + id + '/?live=true&tenant=' + tenant;

    var filterChange = function (filters) {
      $scope.filtersText = "";
      $scope.tags = {};
      filters.forEach(function (filter) {
        $scope.filtersText += filter.title + " : " + filter.value + "\n";
        $scope.tags[filter.id] = filter.value;
      });
    };

    $scope.filterConfig = {
      fields: [
        {
          id: 'type',
          title:  'Type',
          placeholder: 'Filter by Type...',
          filterType: 'select',
          filterValues: ['node', 'cluster', 'ns', 'pod']
        },
        {
          id: 'hostname',
          title:  'Hostname',
          placeholder: 'Filter by Hostname...',
          filterType: 'text'
        },
        {
          id: 'group_id',
          title:  'Group id',
          placeholder: 'Filter by Groups id...',
          filterType: 'text'
        }
      ],
      resultsCount: $scope.items.length,
      appliedFilters: [],
      onFilterChange: filterChange
    };

    var viewSelected = function(viewId) {
      $scope.viewType = viewId;
      if (viewId == 'cardView') {
        $scope.refresh_grahp_data();
      } else {
        $scope.refresh_list_data();
      }
    };

    $scope.viewsConfig = {
      views: [pfViewUtils.getListView(), pfViewUtils.getCardView()],
      onViewSelect: viewSelected
    };
    $scope.viewsConfig.currentView = $scope.viewsConfig.views[0].id;
    $scope.viewType = $scope.viewsConfig.currentView;

    var performAction = function (action) {
      $scope.refresh();
    };

    $scope.actionsConfig = {
      primaryActions: [
        {
          name: 'Filter',
          title: 'Apply filters',
          actionFn: performAction
        }
      ]
    };

    $scope.toolbarConfig = {
      viewsConfig: $scope.viewsConfig,
      filterConfig: $scope.filterConfig,
      actionsConfig: $scope.actionsConfig
    };

    $scope.listConfig = {
      selectionMatchProp: 'i',
      multiSelect: true,
      selectItems: true,
      showSelectBox: false,
      useExpandingRows: true
    };

    $scope.refresh = function() {
      var _tags = $scope.tags != {} ? '&tags=' + JSON.stringify($scope.tags) : '';
      $http.get(url + '&query=metric_definitions' + _tags).success(function(response) {
        'use strict';
        if (response.error) {
          $timeout($scope.refresh, 500);
          return;
        }

        var definitions;
        $scope.items = [];
        $scope.toolbarConfig.filterConfig.resultsCount = $scope.items.length;

        definitions = response.metric_definitions;

        for (var i in definitions) {
          var definition = definitions[i];
          $scope.items[i] = {i: i, definition: definition};
          $scope.loadingDone = false;
          $scope.liveTitle   = '';
          $scope.liveConfig = {
            chartId      : 'liveChart_' + i,
            tooltip      : {
              contents: dailyPodTimeTooltip
            },
            point        : { r: 1 },
            axis         : {
              x: {
                tick: {
                  format: function (value) { return moment(value).utc().format('MM/DD/YYYY HH:mm'); }
                }},
              y: {
                tick: {
                  count: 4,
                  format: function (value) { return formatNumber(value); }
                }}
            },
            subchart: {
                show: true
            }
          };
        };

        $scope.toolbarConfig.filterConfig.resultsCount = $scope.items.length;
        viewSelected('listView');
      });
    };

    $scope.refresh_graph = function(metric_id) {
      console.log(metric_id);
      var ends = new Date().getTime();
      var diff = 60 * 60 * 60 * 1000;
      var starts = ends - diff;
      //var bucket_duration = diff / 1000 / 30;
      var params = '&query=get_data&metric_id=' + metric_id + '&ends=' + ends + '&starts=' + starts;

      $http.get(url + params).success(function(response) {
        'use strict';
        if (response.error) {
          $timeout(function() { $scope.refresh_graph(metric_id); }, 1000);
          return;
        }

        // data
        var n = $scope.items.filter(gr => gr.definition.id == response.id).map(gr => gr.i)[0];

        var definition = $scope.items[n].definition;
        var data       = response.data;
        var xData      = data.filter(d => !d.empty).map(d => d.timestamp || d.start);
        var yData      = data.filter(d => !d.empty).map(d => d.value || d.avg || 0);
        xData.unshift('time');
        yData.unshift(definition.id);

        $scope.liveTitle   = definition.id;
        $scope.liveData["xData"] = xData;
        $scope.liveData["yData" + (n - 1)] = yData;
        $scope.loadingDone = true;
        console.log($scope.liveData);
      });
    };

    $scope.refresh_list = function(metric_id) {
      console.log(metric_id);
      var params = '&query=get_last&metric_id=' + metric_id;

      $http.get(url + params).success(function(response) {
        'use strict';
        if (response.error) {
          $timeout(function() { $scope.refresh_list(metric_id); }, 1000);
          return;
        }

        // data
        var n = $scope.items.filter(gr => gr.definition.id == response.id).map(gr => gr.i)[0];
        $scope.items[n].last_value = response.last_data.value;
      });
    };

    $scope.refresh_grahp_data = function() {
      for (var i in $scope.items) {
        var metric_id = $scope.items[i].definition.id;
        $scope.refresh_graph(metric_id);
      };
    };

    $scope.refresh_list_data = function() {
      for (var i in $scope.items) {
        var metric_id = $scope.items[i].definition.id;
        $scope.refresh_list(metric_id);
      };
    };
  }
]);
