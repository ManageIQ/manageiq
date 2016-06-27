ManageIQ.angular.app.controller('vmCloudAssociateFloatingIpFormController', ['$http', '$scope', 'vmCloudAssociateFloatingIpFormId', 'miqService', function($http, $scope, vmCloudAssociateFloatingIpFormId, miqService) {
  $scope.vmCloudModel = {
    floating_ip: null,
  };
  $scope.floating_ips = [];
  $scope.formId = vmCloudAssociateFloatingIpFormId;
  $scope.modelCopy = angular.copy( $scope.vmCloudModel );

  ManageIQ.angular.scope = $scope;

  $http.get('/vm_cloud/associate_floating_ip_form_fields/' + vmCloudAssociateFloatingIpFormId).success(function(data) {
    $scope.floating_ips = data.floating_ips;
    $scope.modelCopy = angular.copy( $scope.vmCloudModel );
    miqService.sparkleOff();
  });

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/associate_floating_ip_vm/' + vmCloudAssociateFloatingIpFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.submitClicked = function() {
    miqService.sparkleOn();
    var url = '/vm_cloud/associate_floating_ip_vm/' + vmCloudAssociateFloatingIpFormId + '?button=submit';
    miqService.miqAjaxButton(url, true);
  };
}]);
