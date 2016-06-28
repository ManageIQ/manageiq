miqHttpInject(angular.module('containerDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util']))
  .controller('containerDashboardController', ['$scope', 'dashboardUtilsFactory', 'chartsMixin', '$http', '$interval', '$window',
    function($scope, dashboardUtilsFactory, chartsMixin, $http, $interval, $window) {
      document.getElementById("center_div").className += " miq-body";

      // Obj-status cards init
      $scope.objectStatus = {
        providers:  dashboardUtilsFactory.createProvidersStatus(),
        nodes:      dashboardUtilsFactory.createNodesStatus(),
        containers: dashboardUtilsFactory.createContainersStatus(),
        registries: dashboardUtilsFactory.createRegistriesStatus(),
        projects:   dashboardUtilsFactory.createProjectsStatus(),
        pods:       dashboardUtilsFactory.createPodsStatus(),
        services:   dashboardUtilsFactory.createServicesStatus(),
        images:     dashboardUtilsFactory.createImagesStatus(),
        routes:     dashboardUtilsFactory.createRoutesStatus()
      };

      $scope.loadingDone = false;

      // Heatmaps init
      $scope.nodeCpuUsage = {
        title: __('CPU'),
        id: 'nodeCpuUsageMap',
        loadingDone: false
      };

      $scope.nodeMemoryUsage = {
        title: __('Memory'),
        id: 'nodeMemoryUsageMap',
        loadingDone: false
      };

      $scope.heatmaps = [$scope.nodeCpuUsage, $scope.nodeMemoryUsage];
      $scope.nodeHeatMapUsageLegendLabels = chartsMixin.nodeHeatMapUsageLegendLabels;
      $scope.dashboardHeatmapChartHeight = chartsMixin.dashboardHeatmapChartHeight;

      // Node Utilization
      $scope.cpuUsageConfig = chartsMixin.chartConfig.cpuUsageConfig;
      $scope.cpuUsageSparklineConfig = {
        tooltipFn : chartsMixin.dailyTimeTooltip,
        chartId: 'cpuSparklineChart'
      };
      $scope.cpuUsageDonutConfig = {
        chartId: 'cpuDonutChart',
        thresholds: {'warning':'60','error':'90'}
      };
      $scope.memoryUsageConfig = chartsMixin.chartConfig.memoryUsageConfig;
      $scope.memoryUsageSparklineConfig = {
        tooltipFn : chartsMixin.dailyTimeTooltip,
        chartId: 'memorySparklineChart'
      };
      $scope.memoryUsageDonutConfig = {
        chartId: 'memoryDonutChart',
        thresholds: {'warning':'60','error':'90'}
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

        var url = '/container_dashboard/data'+id;
        $http.get(url).success(function(response) {
          'use strict';

          var data = response.data;

          // Obj-status (entity count row)
          var providers = data.providers;
          if (providers) {
            if (id) {
              $scope.providerTypeIconImage = data.providers[0].iconImage
              $scope.isSingleProvider = true
            } else {
              $scope.isSingleProvider = false
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
              $scope.objectStatus.providers.href = data.providers_link
            }
          }

          dashboardUtilsFactory.updateStatus($scope.objectStatus.nodes, data.status.nodes);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.containers, data.status.containers);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.registries, data.status.registries);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.projects, data.status.projects);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.pods, data.status.pods);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.services, data.status.services);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.images, data.status.images);
          dashboardUtilsFactory.updateStatus($scope.objectStatus.routes, data.status.routes);

          // Node utilization donut
          $scope.cpuUsageData = chartsMixin.processUtilizationData(data.ems_utilization.cpu,
                                                                   "dates",
                                                                   $scope.cpuUsageConfig.units);
          $scope.memoryUsageData = chartsMixin.processUtilizationData(data.ems_utilization.mem,
                                                                      "dates",
                                                                      $scope.memoryUsageConfig.units);

          // Heatmaps
          $scope.nodeCpuUsage = chartsMixin.processHeatmapData($scope.nodeCpuUsage, data.heatmaps.nodeCpuUsage);
          $scope.nodeCpuUsage.loadingDone = true;

          $scope.nodeMemoryUsage =
            chartsMixin.processHeatmapData($scope.nodeMemoryUsage, data.heatmaps.nodeMemoryUsage);
          $scope.nodeMemoryUsage.loadingDone = true;

          // Network metrics
          $scope.networkUtilizationDailyConfig = chartsMixin.chartConfig.dailyNetworkUsageConfig;

          $scope.dailyNetworkUtilization =
            chartsMixin.processUtilizationData(data.daily_network_metrics,
                                               "dates",
                                               $scope.networkUtilizationDailyConfig.units);

          // Pod metrics
          $scope.podEntityTrendDailyConfig = chartsMixin.chartConfig.dailyPodUsageConfig;

          $scope.dailyPodEntityTrend =
              chartsMixin.processPodUtilizationData(data.daily_pod_metrics,
                  "dates",
                  $scope.podEntityTrendDailyConfig.createdLabel,
                  $scope.podEntityTrendDailyConfig.deletedLabel);

          // Image metrics
          $scope.imageEntityTrendDailyConfig = chartsMixin.chartConfig.dailyImageUsageConfig;

          $scope.dailyImageEntityTrend =
              chartsMixin.processUtilizationData(data.daily_image_metrics,
                  "dates",
                  $scope.imageEntityTrendDailyConfig.createdLabel);

          // Trend lines data
          $scope.loadingDone = true;
        });
      };
      $scope.refresh();
      var promise = $interval($scope.refresh, 1000*60*3);

      $scope.$on('$destroy', function() {
        $interval.cancel(promise);
      });
    }]);
