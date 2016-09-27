ManageIQ.angular.app.controller('authkeyModalFormController', ['$modalInstance', function ($modalInstance) {
  var $ctrl = this;
  $ctrl.ssh_params = { ssh_user: "",
                       ssh_host: "",
                       ssh_password: ""} ;

  $ctrl.submitForm = function () {
    $modalInstance.close($ctrl.ssh_params);
  };

  $ctrl.cancelForm = function () {
    $modalInstance.dismiss('cancel');
  };
}]);
