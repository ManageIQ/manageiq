ManageIQ.angular.app.controller('mwAddDeploymentController', MwAddDeploymentController);

MwAddDeploymentController.$inject = ['$scope', '$http', 'miqService'];

function MwAddDeploymentController($scope, $http, miqService) {

  $scope.$on('mwAddDeploymentEvent', function(event, data) {
    var fd = new FormData();
    fd.append('file', data.filePath);
    fd.append('id', data.serverId);
    fd.append('enabled', data.enableDeployment);
    fd.append('runtimeName', data.runtimeName);
    $http.post('/middleware_server/add_deployment', fd, {
      transformRequest: angular.identity,
      headers: {'Content-Type': undefined}
    })
      .then(
        function() { // success
          var runtimeName = (typeof data.runtimeName == 'undefined') ? data.filePath.name : data.runtimeName;
          miqService.miqFlash('success', 'Deployment "' + runtimeName + '" has been initiated on this server.');
        },
        function() { // error
          var runtimeName = (typeof data.runtimeName == 'undefined') ? data.filePath.name : data.runtimeName;
          miqService.miqFlash('error', 'Unable to deploy "' + runtimeName + '" on this server.');
        })
      .finally(function() {
        angular.element("#modal_d_div").modal('hide');
        miqService.sparkleOff();
      });
  });
}
