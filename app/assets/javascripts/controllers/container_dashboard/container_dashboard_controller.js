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
                title: 'CPU',
                id: 'nodeCpuUsageMap',
                loadingDone: false
            };

            $scope.nodeMemoryUsage = {
                title: 'Memory',
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

            $scope.refresh = function() {
                var id;
                if ($location.absUrl().match("show/$") || $location.absUrl().match("show$")) {
                    id = '';
                }
                else {
                    id = '/'+ (/container_dashboard\/show\/(\d+)/.exec($location.absUrl())[1]);
                }

                var url = '/container_dashboard/data'+id;
                $http.get(url).success(function(response) {
                    'use strict';

                    var data = response.data;

                    // Obj-status (entity count row)
                    var providers = data.providers;
                    if (providers)
                    {
                        $scope.objectStatus.providers.count = 0;
                        $scope.objectStatus.providers.notifications = [];
                        providers.forEach(function (item) {
                            $scope.objectStatus.providers.count += item.count;
                            $scope.objectStatus.providers.notifications.push({
                                iconClass: item.iconClass,
                                count: item.count
                            })
                        });

                        if ($scope.objectStatus.providers.count > 0){
                                $scope.objectStatus.providers.href = data.providers_link
                        }
                    }

                    dashboardUtilsFactory.updateStatus($scope.objectStatus.nodes,      data.status.nodes);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.containers, data.status.containers);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.registries, data.status.registries);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.projects,   data.status.projects);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.pods,       data.status.pods);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.services,   data.status.services);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.images,     data.status.images);
                    dashboardUtilsFactory.updateStatus($scope.objectStatus.routes,     data.status.routes);

                    // Node utilization donut
                    $scope.cpuUsageData = data.ems_utilization.cpu;
                    $scope.memoryUsageData = data.ems_utilization.mem;
                    $scope.utilizationLoadingDone = true;

                    // Heatmaps
                    $scope.nodeCpuUsage.data = data.heatmaps.nodeCpuUsage.sort(dashboardUtilsFactory.heatmapSort);
                    $scope.nodeCpuUsage.loadingDone = true;
                    $scope.nodeMemoryUsage.data = data.heatmaps.nodeMemoryUsage.sort(dashboardUtilsFactory.heatmapSort);
                    $scope.nodeMemoryUsage.loadingDone = true;
                });
        };
        $scope.refresh();
        var promise = $interval($scope.refresh, 1000*60*3);

        $scope.$on('$destroy', function() {
            $interval.cancel(promise);
        });
    }]);
