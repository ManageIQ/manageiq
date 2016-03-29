ManageIQ.angular.app.controller('vmCloudFormController', ['$http', '$scope', 'vmCloudFormId', 'miqService', function($http, $scope, vmCloudFormId, miqService) {
  $scope.vmCloudModel = { name: '' };
  $scope.formId = vmCloudFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $scope.attachClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/attach_volume/' + vmCloudFormId + '?button=attach';
    miqService.miqAjaxButton(url, true);
  };

  $scope.detachClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/detach_volume/' + vmCloudFormId + '?button=detach';
    miqService.miqAjaxButton(url, true);
  };

  $scope.cancelAttachClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/attach_volume/' + vmCloudFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.cancelDetachClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/detach_volume/' + vmCloudFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.resetClicked = function() {
    $scope.cloudVolumeModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
