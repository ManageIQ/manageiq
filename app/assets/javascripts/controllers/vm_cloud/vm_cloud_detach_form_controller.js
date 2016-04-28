ManageIQ.angular.app.controller('vmCloudDetachFormController', ['$http', '$scope', 'vmCloudDetachFormId', 'miqService', function($http, $scope, vmCloudDetachFormId, miqService) {
  $scope.vmCloudModel = { name: '' };
  $scope.formId = vmCloudDetachFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $scope.submitClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/detach_volume/' + vmCloudDetachFormId + '?button=detach';
    miqService.miqAjaxButton(url, true);
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/detach_volume/' + vmCloudDetachFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.resetClicked = function() {
    $scope.vmCloudModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
