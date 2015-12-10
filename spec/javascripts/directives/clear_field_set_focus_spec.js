describe('clearFieldSetFocus initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope, _miqService_) {
    $scope = $rootScope;
    miqService = _miqService_;

    var element = angular.element(
      '<form name="angularForm">' +
      '<input clear-field-set-focus type="text" ng-model="hostModel.password" name="password"/>' +
      '<input clear-field-set-focus="no-focus" type="text" ng-model="hostModel.password_verify" name="password_verify"/>' +
      '</form>'
    );
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
    $scope.model = "hostModel";
    $scope.bChangeStoredPassword = false;
    $scope.bCancelPasswordChange = false;
    $scope.hostModel = {'password': '', 'password_verify': ''};
    $scope.hostModel.password = miqService.storedPasswordPlaceholder;
    $scope.hostModel.password_verify = miqService.storedPasswordPlaceholder;
  }));

  describe('clear-field-set-focus specs', function() {
    it('sets focus on the password field and clears out the placeholder', inject(function($timeout) {
      spyOn(elem[0][0], 'focus');
      $scope.bChangeStoredPassword = true;
      $timeout.flush();
      expect($scope.hostModel.password).toBe('');
      expect((elem[0][0]).focus).toHaveBeenCalled();
    }));

    it('clears out the placeholder in the password verify field', inject(function($timeout) {
      spyOn(elem[0][1], 'focus');
      $scope.bChangeStoredPassword = true;
      $timeout.flush();
      expect($scope.hostModel.password_verify).toBe('');
      expect((elem[0][1]).focus).not.toHaveBeenCalled();
    }));

    it('puts back the placeholder when cancel password change is selected', inject(function($timeout) {
      $scope.bCancelPasswordChange = true;
      $timeout.flush();
      expect($scope.hostModel.password).toBe(miqService.storedPasswordPlaceholder);
      expect($scope.hostModel.password_verify).toBe(miqService.storedPasswordPlaceholder);
    }));
  });
});