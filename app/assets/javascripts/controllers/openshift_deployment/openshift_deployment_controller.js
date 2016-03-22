miqHttpInject(angular.module('openshiftDeployment', ['ui.bootstrap', 'patternfly', 'patternfly.charts', 'miq.card']))
    .controller('openshiftDeploymentController', ['$scope', '$http', '$interval', "$location",
        function($scope, $http, $interval, $location) {
            $http.get("data")
                .then(function(response) {
                    $scope.providers = response.data.data.providers;
                    $scope.types = ["OpenShift Enterprise", "OpenShift Origin", "Atomic Enterprise"]
                    $scope.deployment_options = ["Managed Exisiting", "Managed Provision", "None Managed"]

                });
        }]);

