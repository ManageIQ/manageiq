ManageIQ.angular.app.controller('authkeyModalFormController', ['$modalInstance', 'ssh_params', function ($modalInstance, ssh_params) {
  var $ctrl = this;
  $ctrl.ssh_params = ssh_params;

  $ctrl.$onInit = function () {
    $ctrl.ssh_params = $ctrl.resolve.ssh_params;
  };

  $ctrl.submitForm = function () {
    $modalInstance.close($ctrl.ssh_params);
  };

  $ctrl.cancelForm = function () {
    $modalInstance.dismiss('cancel');
  };
}]);
