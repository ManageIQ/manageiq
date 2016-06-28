ManageIQ.angular.app.controller('vmCloudDisassociateFloatingIpFormController', ['$http', '$scope', 'vmCloudDisassociateFloatingIpFormId', 'miqService', function($http, $scope, vmCloudDisassociateFloatingIpFormId, miqService) {
  $scope.vmCloudModel = {
    floating_ip: null,
  };
  $scope.floating_ips = [];
  $scope.formId = vmCloudDisassociateFloatingIpFormId;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $http.get('/vm_cloud/disassociate_floating_ip_form_fields/' + vmCloudDisassociateFloatingIpFormId).success(function(data) {
    $scope.floating_ips = data.floating_ips;
    $scope.modelCopy = angular.copy( $scope.vmCloudModel );
    miqService.sparkleOff();
  });

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/disassociate_floating_ip_vm/' + vmCloudDisassociateFloatingIpFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.submitClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/disassociate_floating_ip_vm/' + vmCloudDisassociateFloatingIpFormId + '?button=submit';
    miqService.miqAjaxButton(url, true);
  };
}]);
