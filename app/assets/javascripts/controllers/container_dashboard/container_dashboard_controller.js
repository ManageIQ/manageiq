angular.module('containerDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util'])
  .config(['$httpProvider', function($httpProvider) {
    $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
  }])
  .controller('containerDashboardController', ['$scope', 'dashboardUtilsFactory', 'chartsMixin', '$http', '$interval', "$location",
    function($scope, dashboardUtilsFactory, chartsMixin, $http, $interval, $location) {
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
        tooltipType: 'valuePerDay',
        chartId: 'cpuSparklineChart'
      };
      $scope.cpuUsageDonutConfig = {
        chartId: 'cpuDonutChart',
        thresholds: {'warning':'60','error':'90'}
      };
      $scope.memoryUsageConfig = chartsMixin.chartConfig.memoryUsageConfig;
      $scope.memoryUsageSparklineConfig = {
        tooltipType: 'valuePerDay',
        chartId: 'memorySparklineChart'
      };
      $scope.memoryUsageDonutConfig = {
        chartId: 'memoryDonutChart',
        thresholds: {'warning':'60','error':'90'}
      };

      $scope.nodeCpuUsage.loadingDone = false;
      $scope.nodeMemoryUsage.loadingDone = false;

      // Network
      $scope.networkUtilizationLoadingDone = false;

      $scope.refresh = function() {
        var id;
        if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
          id = '';
        }
        else {
          id = '/'+ (/ems_container\/show\/(\d+)/.exec($location.absUrl())[1]);
        }

        var url = '/container_dashboard/data'+id;
        $http.get(url).success(function(response) {
          'use strict';

          var data = response.data;

          // Obj-status (entity count row)
          var providers = data.providers;
          if (providers) {
            if (id) {
              $scope.providerTypeIconClass = dashboardUtilsFactory.iconClassForProvider(data.providers[0].providerType);
            } else {
              $scope.objectStatus.providers.count = 0;
              $scope.objectStatus.providers.notifications = [];
              providers.forEach(function (item) {
                $scope.objectStatus.providers.count += item.count;
                $scope.objectStatus.providers.notifications.push({
                  iconClass: dashboardUtilsFactory.iconClassForProvider(item.providerType),
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
          $scope.utilizationLoadingDone = true;

          // Heatmaps
          $scope.nodeCpuUsage = chartsMixin.processHeatmapData($scope.nodeCpuUsage, data.heatmaps.nodeCpuUsage);
          $scope.nodeCpuUsage.loadingDone = true;

          $scope.nodeMemoryUsage =
            chartsMixin.processHeatmapData($scope.nodeMemoryUsage, data.heatmaps.nodeMemoryUsage);
          $scope.nodeMemoryUsage.loadingDone = true;

          // Network metrics
          $scope.networkUtilizationHourlyConfig = chartsMixin.chartConfig.hourlyNetworkUsageConfig;
          $scope.networkUtilizationDailyConfig = chartsMixin.chartConfig.dailyNetworkUsageConfig;

          if (data.hourly_network_metrics != undefined) {
           data.hourly_network_metrics.xData = data.hourly_network_metrics.xData.map(function (date) {
              return dashboardUtilsFactory.parseDate(date)
            });
          }

          $scope.hourlyNetworkUtilization =
            chartsMixin.processUtilizationData(data.hourly_network_metrics,
                                               "dates",
                                               $scope.networkUtilizationHourlyConfig.units)

          $scope.dailyNetworkUtilization =
            chartsMixin.processUtilizationData(data.daily_network_metrics,
                                               "dates",
                                               $scope.networkUtilizationDailyConfig.units);
          $scope.networkUtilizationLoadingDone = true;
        });
      };
      $scope.refresh();
      var promise = $interval($scope.refresh, 1000*60*3);

      $scope.$on('$destroy', function() {
          $interval.cancel(promise);
      });
    }]);
