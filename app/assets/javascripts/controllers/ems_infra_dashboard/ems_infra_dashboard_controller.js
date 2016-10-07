/* global miqHttpInject */

miqHttpInject(angular.module('emsInfraDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util']))
  .controller('emsInfraDashboardController', ['$scope', 'infraDashboardUtilsFactory', 'infraChartsMixin', '$http', '$interval', '$window',
    function($scope, infraDashboardUtilsFactory, infraChartsMixin, $http, $interval, $window) {
      document.getElementById("center_div").className += " miq-body";

      // Obj-status cards init
      $scope.objectStatus = {
        providers:     infraDashboardUtilsFactory.createProvidersIcon(),
        ems_clusters:  infraDashboardUtilsFactory.createClustersStatus(),
        hosts:         infraDashboardUtilsFactory.createHostsStatus(),
        datastores:    infraDashboardUtilsFactory.createDatastoresStatus(),
        vms:           infraDashboardUtilsFactory.createVmsStatus(),
        miq_templates: infraDashboardUtilsFactory.createMiqTemplatesStatus(),
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
      $scope.clusterHeatMapUsageLegendLabels = infraChartsMixin.clusterHeatMapUsageLegendLabels;
      $scope.dashboardHeatmapChartHeight = infraChartsMixin.dashboardHeatmapChartHeight;

      // cluster Utilization
      $scope.cpuUsageConfig = infraChartsMixin.chartConfig.cpuUsageConfig;
      $scope.cpuUsageSparklineConfig = {
        tooltipFn: infraChartsMixin.dailyTimeTooltip,
        chartId: 'cpuSparklineChart'
      };
      $scope.cpuUsageDonutConfig = {
        chartId: 'cpuDonutChart',
        thresholds: { 'warning': '60', 'error': '90' },
      };
      $scope.memoryUsageConfig = infraChartsMixin.chartConfig.memoryUsageConfig;
      $scope.memoryUsageSparklineConfig = {
        tooltipFn: infraChartsMixin.dailyTimeTooltip,
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

          infraDashboardUtilsFactory.updateStatus($scope.objectStatus.ems_clusters, data.status.ems_clusters);
          infraDashboardUtilsFactory.updateStatus($scope.objectStatus.hosts, data.status.hosts);
          infraDashboardUtilsFactory.updateStatus($scope.objectStatus.datastores, data.status.datastores);
          infraDashboardUtilsFactory.updateStatus($scope.objectStatus.vms, data.status.vms);
          infraDashboardUtilsFactory.updateStatus($scope.objectStatus.miq_templates, data.status.miq_templates);

          // cluster utilization donut
          $scope.cpuUsageData = infraChartsMixin.processUtilizationData(data.ems_utilization.cpu,
                                                                   "dates",
                                                                   $scope.cpuUsageConfig.units);
          $scope.memoryUsageData = infraChartsMixin.processUtilizationData(data.ems_utilization.mem,
                                                                      "dates",
                                                                      $scope.memoryUsageConfig.units);

          // Heatmaps
          $scope.clusterCpuUsage = infraChartsMixin.processHeatmapData($scope.clusterCpuUsage, data.heatmaps.clusterCpuUsage);
          $scope.clusterCpuUsage.loadingDone = true;

          $scope.clusterMemoryUsage =
            infraChartsMixin.processHeatmapData($scope.clusterMemoryUsage, data.heatmaps.clusterMemoryUsage);
          $scope.clusterMemoryUsage.loadingDone = true;

          // Recent Hosts
          $scope.recentHostsConfig = infraChartsMixin.chartConfig.recentHostsConfig;

          // recent Hosts chart
          $scope.recentHostsData = infraChartsMixin.processRecentHostsData(data.recentHosts,
            "dates",
            $scope.recentHostsConfig.label);

          // Recent VMs
          $scope.recentVmsConfig = infraChartsMixin.chartConfig.recentVmsConfig;

          // recent VMS chart
          $scope.recentVmsData = infraChartsMixin.processRecentVmsData(data.recentVms,
            "dates",
            $scope.recentVmsConfig.label);

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
