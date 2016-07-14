ManageIQ.angular.app.controller('middlewareAddDeploymentController', MiddlewareDeploymentCtrl);

MiddlewareDeploymentCtrl.$inject = ['$scope', '$http', 'miqService'];

function MiddlewareDeploymentCtrl($scope, $http, miqService) {
  ManageIQ.angular.scope = $scope;

  $scope.showListener = function () {
    $scope.showDeployModal = true;
    $scope.resetDeployForm();
  };

  $scope.enableDeployment = true;

  $scope.$watch('filePath', function(newValue) {
    if (newValue) {
      $scope.runtimeName = newValue.name;
    }
  });

  $scope.addDeployment = function () {
    miqService.sparkleOn();
    var url = '/middleware_server/add_deployment';
    $scope.uploadFile($scope.filePath, url);
  };

  $scope.resetDeployForm = function () {
    $scope.enableDeployment = true;
    $scope.runtimeName = undefined;
    $scope.filePath = undefined;
    angular.element('#deploy_div :file#upload_file').val('');
    angular.element('#deploy_div input[type="text"]:disabled').val('');
  };

  $scope.uploadFile = function (file, uploadUrl) {
    var fd = new FormData();
    fd.append('file', file);
    fd.append('id', angular.element('#server_id').val());
    fd.append('enabled', $scope.enableDeployment);
    fd.append('runtimeName', $scope.runtimeName);
    $http.post(uploadUrl, fd, {
      transformRequest: angular.identity,
      headers: {'Content-Type': undefined}
    })
    .then(
      function() { // success
        miqService.miqFlash('success', 'Deployment "' + $scope.runtimeName + '" has been initiated on this server.');
      },
      function() { // error
        miqService.miqFlash('error', 'Unable to deploy "' + $scope.runtimeName + '" on this server.');
      })
    .finally(function() {
      angular.element("#modal_d_div").modal('hide');
      miqService.sparkleOff();
    });
  }

}
