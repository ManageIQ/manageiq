ManageIQ.angular.app.controller('vmCloudEvacuateFormController', ['$http', '$scope', 'vmCloudEvacuateFormId', 'miqService', function($http, $scope, vmCloudEvacuateFormId, miqService) {
  $scope.vmCloudModel = {
    destination_host_id: null,
    on_shared_storage:   true,
    admin_password:      null
  };
  $scope.clusters = [];
  $scope.hosts = [];
  $scope.filtered_hosts = [];
  $scope.formId = vmCloudEvacuateFormId;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $http.get('/vm_cloud/evacuate_form_fields/' + vmCloudEvacuateFormId).success(function(data) {
    $scope.clusters = data.clusters;
    $scope.hosts = data.hosts;
    $scope.modelCopy = angular.copy( $scope.vmCloudModel );
    miqService.sparkleOff();
  });

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/evacuate_vm/' + vmCloudEvacuateFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.submitClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/evacuate_vm/' + vmCloudEvacuateFormId + '?button=submit';
    miqService.miqAjaxButton(url, true);
  };
}]);
