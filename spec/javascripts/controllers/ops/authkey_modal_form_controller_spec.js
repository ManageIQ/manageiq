describe('authkeyModalFormController', function () {

  beforeEach(module('ManageIQ'));

  var Ctrl;
  var scope;
  var modalInstance;

  // Initialize the controller and a mock scope
  beforeEach(inject(
      function ($controller, $rootScope) {     // Don't bother injecting a 'real' modal
        scope = $rootScope.$new();
        modalInstance = {                    // Create a mock object using spies
          close: jasmine.createSpy('modalInstance.close'),
          dismiss: jasmine.createSpy('modalInstance.dismiss'),
          result: {
            then: jasmine.createSpy('modalInstance.result.then')
          }
        };
        Ctrl = $controller('authkeyModalFormController', {
          $scope: scope,
          $modalInstance: modalInstance,
          ssh_params: {ssh_host: "", ssh_user: "", ssh_password: ""}
        });
      })
  );

  describe('Initial state', function () {
    it('should instantiate the controller properly', function () {
      expect(Ctrl).not.toBeUndefined();
    });

it('should close the modal with result "true" when accepted', function () {
  Ctrl.ssh_params =  {ssh_host: "testhost", ssh_user: "testuser", ssh_password: "testpwd"};
  Ctrl.submitForm();
  expect(modalInstance.close).toHaveBeenCalledWith( {ssh_host: "testhost", ssh_user: "testuser", ssh_password: "testpwd"});
});

it('should close the modal with result "false" when rejected', function () {
  Ctrl.cancelForm();
  expect(modalInstance.dismiss).toHaveBeenCalled();
});
});

});
