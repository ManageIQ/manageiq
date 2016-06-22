ManageIQ.angular.app.controller('middlewareAddDeploymentController', MiddlewareDeploymentCtrl);

MiddlewareDeploymentCtrl.$inject = ['$scope', '$http', 'miqService'];

function MiddlewareDeploymentCtrl($scope, $http, miqService) {
  ManageIQ.angular.scope = $scope;

  $scope.showListener = function () {
    $scope.showDeployModal = true;
  };

  $scope.addDeployment = function () {
    miqService.sparkleOn();
    var url = '/middleware_server/add_deployment';
    $scope.uploadFile($scope.filePath, url);
  };
    
  $scope.uploadFile = function (file, uploadUrl) {
    var fd = new FormData();
    fd.append('file', file);
    fd.append('id', angular.element('#server_id').val());
    $http.post(uploadUrl, fd, {
      transformRequest: angular.identity,
      headers: {'Content-Type': undefined}
    })
    .then(
      function() { // success
        miqService.miqFlash('success', 'Deployment "' + file.name + '" has been initiated on this server.');
      },
      function() { // error
        miqService.miqFlash('error', 'Unable to deploy "' + file.name + '" on this server.');
      })
    .finally(function() {
      angular.element("#modal_d_div").modal('hide');
      miqService.sparkleOff();
    });
  }

}
