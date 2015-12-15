angular.module('containerDashboard', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card', 'miq.util'])
    .config(['$httpProvider', function($httpProvider) {
        $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
    }])
    .controller('containerDashboardController', ['$scope', 'miq.util', 'ChartsDataMixin', '$http', '$interval', "$location",
        function($scope, containerDashboardUtils, chartsDataMixin, $http, $interval, $location) {
            document.getElementById("center_div").className += " miq-body";

            $scope.objectStatus = containerDashboardUtils.createAllStatuses();

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
            $scope.dashboardHeatmapChartHeight = chartsDataMixin.dashboardHeatmapChartHeight;

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

                    // Update entity counts
                    containerDashboardUtils.updateAllStatuses($scope.objectStatus, data.status)

                    // Heatmaps
                    $scope.nodeCpuUsage.data = data.heatmaps.nodeCpuUsage.sort(containerDashboardUtils.heatmapSort);
                    $scope.nodeCpuUsage.loadingDone = true;
                    $scope.nodeMemoryUsage.data = data.heatmaps.nodeMemoryUsage.sort(containerDashboardUtils.heatmapSort);
                    $scope.nodeMemoryUsage.loadingDone = true;

                });
        };
        $scope.refresh();
        var promise = $interval($scope.refresh, 1000*60*3);

        $scope.$on('$destroy', function() {
            $interval.cancel(promise);
        });
    }]);
