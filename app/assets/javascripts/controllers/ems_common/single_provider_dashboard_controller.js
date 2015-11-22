angular.module('containerDashboard')
    .config(['$httpProvider', function($httpProvider) {
        $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
    }])
    .controller('singleProviderDashboardController', ['$scope','ContainerDashboardUtils', '$http', '$interval', "$location",
        function($scope, containerDashboardUtils, $http, $interval, $location) {
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

            $scope.refresh = function() {
                var id = '/'+ (/ems_container\/show\/(\d+)/.exec($location.absUrl())[1]);
                var url = '/container_dashboard/data'+id;

                $http.get(url).success(function(response) {
                    'use strict';

                    var data = response.data;
                    $scope.providerTypeIconClass = data.providers.iconClass;

                    containerDashboardUtils.updateStatus($scope.objectStatus.nodes,      data.status.nodes);
                    containerDashboardUtils.updateStatus($scope.objectStatus.containers, data.status.containers);
                    containerDashboardUtils.updateStatus($scope.objectStatus.registries, data.status.registries);
                    containerDashboardUtils.updateStatus($scope.objectStatus.projects,   data.status.projects);
                    containerDashboardUtils.updateStatus($scope.objectStatus.pods,       data.status.pods);
                    containerDashboardUtils.updateStatus($scope.objectStatus.services,   data.status.services);
                    containerDashboardUtils.updateStatus($scope.objectStatus.images,     data.status.images);
                    containerDashboardUtils.updateStatus($scope.objectStatus.routes,     data.status.routes);
                });
            };
            $scope.refresh();
            var promise = $interval( $scope.refresh, 1000*60*3);

            $scope.$on('$destroy', function() {
                $interval.cancel(promise);
            });
        }]);
