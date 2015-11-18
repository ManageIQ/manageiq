angular.module('containerDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.charts', 'miq.card', 'miq.util'])
    .config(['$httpProvider', function($httpProvider) {
        $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
    }])
    .controller('containerDashboardController', ['$scope', 'miq.util', 'ChartsDataMixin', '$http', '$interval', "$location",
        function($scope, containerDashboardUtils, chartsDataMixin, $http, $interval, $location) {
            document.getElementById("center_div").className += " miq-body";

            $scope.objectStatus = {
                providers:  containerDashboardUtils.createProvidersStatus(),
                nodes:      containerDashboardUtils.createNodesStatus(),
                containers: containerDashboardUtils.createContainersStatus(),
                registries: containerDashboardUtils.createRegistriesStatus(),
                projects:   containerDashboardUtils.createProjectsStatus(),
                pods:       containerDashboardUtils.createPodsStatus(),
                services:   containerDashboardUtils.createServicesStatus(),
                images:     containerDashboardUtils.createImagesStatus(),
                routes:     containerDashboardUtils.createRoutesStatus()
            };

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
            $scope.nodeHeatMapUsageLegendLabels = chartsDataMixin.nodeHeatMapUsageLegendLabels;
            $scope.chartHeight = chartsDataMixin.dashboardSparklineChartHeight;
            $scope.dashboardHeatmapChartHeight = chartsDataMixin.dashboardHeatmapChartHeight;

            $scope.utilizationLoadingDone = false;

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
                    }

                    containerDashboardUtils.updateStatus($scope.objectStatus.nodes,      data.status.nodes);
                    containerDashboardUtils.updateStatus($scope.objectStatus.containers, data.status.containers);
                    containerDashboardUtils.updateStatus($scope.objectStatus.registries, data.status.registries);
                    containerDashboardUtils.updateStatus($scope.objectStatus.projects,   data.status.projects);
                    containerDashboardUtils.updateStatus($scope.objectStatus.pods,       data.status.pods);
                    containerDashboardUtils.updateStatus($scope.objectStatus.services,   data.status.services);
                    containerDashboardUtils.updateStatus($scope.objectStatus.images,     data.status.images);
                    containerDashboardUtils.updateStatus($scope.objectStatus.routes,     data.status.routes);

                    // node utilization
                    $scope.cpuUsageConfig = chartConfig.cpuUsageConfig;
                    $scope.cpuUsageSparklineConfig = {
                        tooltipType: 'valuePerDay',
                        chartId: 'cpuSparklineChart',
                        sparklineChartHeight: $scope.chartHeight
                    };
                    $scope.cpuUsageDonutConfig = {
                        chartId: 'cpuDonutChart',
                        thresholds: {'warning':'60','error':'90'}
                    };
                    $scope.memoryUsageConfig = chartConfig.memoryUsageConfig;
                    $scope.memoryUsageSparklineConfig = {
                        tooltipType: 'valuePerDay',
                        chartId: 'memorySparklineChart',
                        sparklineChartHeight: $scope.chartHeight
                    };
                    $scope.memoryUsageDonutConfig = {
                        chartId: 'memoryDonutChart',
                        thresholds: {'warning':'60','error':'90'}
                    };

                    // Node utilization
                    $scope.cpuUsageData = data.node_utilization.cpu;
                    $scope.memoryUsageData = data.node_utilization.mem;
                    $scope.utilizationLoadingDone = true;

                    // Heatmaps
                    $scope.nodeCpuUsage.data = data.heatmaps.nodeCpuUsage;
                    $scope.nodeCpuUsage.loadingDone = true;
                    $scope.nodeMemoryUsage.data = data.heatmaps.nodeMemoryUsage;
                    $scope.nodeMemoryUsage.loadingDone = true;
                });
        };
        $scope.refresh();
        var promise = $interval($scope.refresh, 1000*60*3);

        $scope.$on('$destroy', function() {
            $interval.cancel(promise);
        });
    }]);
