/* global miqHttpInject */

miqHttpInject(angular.module('emsInfraDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util']))
  .controller('emsInfraDashboardController', ['$scope', 'dashboardUtilsFactory', 'chartsMixin', '$http', '$interval', '$window',
    function($scope, dashboardUtilsFactory, chartsMixin, $http, $interval, $window) {
      document.getElementById("center_div").className += " miq-body";

      // Obj-status cards init
      $scope.objectStatus = {
        providers:     dashboardUtilsFactory.createProvidersStatus(),
        ems_clusters:  dashboardUtilsFactory.createClustersStatus(),
        hosts:         dashboardUtilsFactory.createHostsStatus(),
        datastores:    dashboardUtilsFactory.createDatastoresStatus(),
        vms:           dashboardUtilsFactory.createVmsStatus(),
        miq_templates: dashboardUtilsFactory.createMiqTemplatesStatus(),
      };

      $scope.loadingDone = false;

      // Heatmaps init
      $scope.clusterCpuUsage = {
        title: __('CPU'),
        id: 'clusterCpuUsageMap',
        loadingDone: false
      };

      $scope.clusterMemoryUsage = {
        title: __('Memory'),
        id: 'clusterMemoryUsageMap',
        loadingDone: false
      };

      $scope.heatmaps = [$scope.clusterCpuUsage, $scope.clusterMemoryUsage];
      $scope.clusterHeatMapUsageLegendLabels = chartsMixin.clusterHeatMapUsageLegendLabels;
      $scope.dashboardHeatmapChartHeight = chartsMixin.dashboardHeatmapChartHeight;

      // cluster Utilization
      $scope.cpuUsageConfig = chartsMixin.chartConfig.cpuUsageConfig;
      $scope.cpuUsageSparklineConfig = {
        tooltipFn: chartsMixin.dailyTimeTooltip,
        chartId: 'cpuSparklineChart'
      };
      $scope.cpuUsageDonutConfig = {
        chartId: 'cpuDonutChart',
        thresholds: { 'warning': '60', 'error': '90' },
      };
      $scope.memoryUsageConfig = chartsMixin.chartConfig.memoryUsageConfig;
      $scope.memoryUsageSparklineConfig = {
        tooltipFn: chartsMixin.dailyTimeTooltip,
        chartId: 'memorySparklineChart'
      };
      $scope.memoryUsageDonutConfig = {
        chartId: 'memoryDonutChart',
        thresholds: { 'warning': '60', 'error': '90' },
      };

      $scope.refresh = function() {
        var id;
        // get the pathname and remove trailing / if exist
        var pathname = $window.location.pathname.replace(/\/$/, '');
        if (pathname.match(/show$/)) {
          id = '';
        } else {
          // search for pattern ^/<controler>/<id>$ in the pathname
          id = '/' + (/^\/[^\/]+\/(\d+)$/.exec(pathname)[1]);
        }

        var url = '/ems_infra_dashboard/data' + id;
        $http.get(url).success(function(response) {
          'use strict';

          var data = response.data;

          // Obj-status (entity count row)
          var providers = data.providers;
          if (providers) {
            if (id) {
              $scope.providerTypeIconImage = data.providers[0].iconImage;
              $scope.isSingleProvider = true;
            } else {
              $scope.isSingleProvider = false;
              $scope.objectStatus.providers.count = 0;
              $scope.objectStatus.providers.notifications = [];
              providers.forEach(function (item) {
                $scope.objectStatus.providers.count += item.count;
                $scope.objectStatus.providers.notifications.push({
                  iconImage: item.iconImage,
                  count: item.count
                })
              });
            }

            if ($scope.objectStatus.providers.count > 0) {
              $scope.objectStatus.providers.href = data.providers_link;
            }
          }

          dashboardUtilsFactory.updateStatus($scope.objectStatus.ems_clusters, data.status.ems_clusters);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.hosts, data.status.hosts);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.datastores, data.status.datastores);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.vms, data.status.vms);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.miq_templates, data.status.miq_templates);

          // cluster utilization donut
          $scope.cpuUsageData = chartsMixin.processUtilizationData(data.ems_utilization.cpu,
                                                                   "dates",
                                                                   $scope.cpuUsageConfig.units);
          $scope.memoryUsageData = chartsMixin.processUtilizationData(data.ems_utilization.mem,
                                                                      "dates",
                                                                      $scope.memoryUsageConfig.units);

          // Heatmaps
          $scope.clusterCpuUsage = chartsMixin.processHeatmapData($scope.clusterCpuUsage, data.heatmaps.clusterCpuUsage);
          $scope.clusterCpuUsage.loadingDone = true;

          $scope.clusterMemoryUsage =
            chartsMixin.processHeatmapData($scope.clusterMemoryUsage, data.heatmaps.clusterMemoryUsage);
          $scope.clusterMemoryUsage.loadingDone = true;

          // Trend lines data
          $scope.loadingDone = true;
        });
      };
      $scope.refresh();
      var promise = $interval($scope.refresh, 1000 * 60 * 3);

      $scope.$on('$destroy', function() {
        $interval.cancel(promise);
      });
    }]);
