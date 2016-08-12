ManageIQ.angular.app.controller('middlewareAddDataSourceController', MiddlewareAddDataSourceCtrl);

MiddlewareAddDataSourceCtrl.$inject = ['$scope', '$http', 'miqService'];

function MiddlewareAddDataSourceCtrl($scope, $http, miqService) {
  ManageIQ.angular.scope = $scope;

  $scope.showListener = function () {
    $scope.showDataSourceAddModal = true;
    $scope.resetAddDataSourceForm();
  };

  $scope.enableDeployment = true;

  $scope.$watch('filePath', function(newValue) {
    if (newValue) {
      $scope.runtimeName = newValue.name;
    }
  });

  $scope.addDataSource = function () {
    miqService.sparkleOn();
    var url = '/middleware_server/add_deployment';
    $scope.uploadFile($scope.filePath, url);
  };

  $scope.uploadFile = function (file, uploadUrl) {
    var fd = new FormData();
    fd.append('file', file);
    fd.append('id', angular.element('#ds_server_id').val());
    fd.append('enabled', $scope.enableDeployment);
    fd.append('runtimeName', $scope.runtimeName);
    $http.post(uploadUrl, fd, {
      transformRequest: angular.identity,
      headers: {'Content-Type': undefined}
    })
      .then(
        function() { // success
          miqService.miqFlash('success', 'Datasource has been successfully added to this server: "' + $scope.runtimeName + '" has been initiated on this server.');
        },
        function() { // error
          miqService.miqFlash('error', 'Failed to add datasource"')
        })
      .finally(function() {
        angular.element("#modal_ds_div").modal('hide');
        miqService.sparkleOff();
      });
  };

  $scope.resetAddDataSourceForm = function () {
    $scope.enableDeployment = true;
    $scope.runtimeName = undefined;
    $scope.filePath = undefined;
    angular.element('#ds_add_div :file#upload_file').val('');
    angular.element('#ds_add_div input[type="text"]:disabled').val('');
  };

}
