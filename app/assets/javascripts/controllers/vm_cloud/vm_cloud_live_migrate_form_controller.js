ManageIQ.angular.app.controller('vmCloudLiveMigrateFormController', ['$http', '$scope', 'vmCloudLiveMigrateFormId', 'miqService', function($http, $scope, vmCloudLiveMigrateFormId, miqService) {
  $scope.vmCloudModel = {
    auto_select_host:    true,
    cluster_id:          null,
    destination_host_id: null,
    block_migration:     null,
    disk_over_commit:    null
  };
  $scope.clusters = [];
  $scope.hosts = [];
  $scope.filtered_hosts = [];
  $scope.formId = vmCloudLiveMigrateFormId;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $http.get('/vm_cloud/live_migrate_form_fields/' + vmCloudLiveMigrateFormId).success(function(data) {
    $scope.clusters = data.clusters;
    $scope.hosts = data.hosts;
    $scope.modelCopy = angular.copy( $scope.vmCloudModel );
    miqService.sparkleOff();
  });

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/live_migrate_vm/' + vmCloudLiveMigrateFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.submitClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/live_migrate_vm/' + vmCloudLiveMigrateFormId + '?button=submit';
    miqService.miqAjaxButton(url, true);
  };
}]);
