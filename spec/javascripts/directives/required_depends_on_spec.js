describe('requiredDependsOn initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.model = "hostModel";
    var element = angular.element(
      '<form name="angularForm">' +
      '<input required-depends-on="ipmi_userid" type="text" ng-model="hostModel.ipmi_address" name="ipmi_address"/>' +
      '<input type="text" ng-model="hostModel.ipmi_userid" name="ipmi_userid"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;
  }));

  describe('required-depends-on', function() {
    it('sets the form to invalid if ipmi_userid is filled in and ipmi_address is blank', function() {
      $scope.hostModel = {'ipmi_address': '', 'ipmi_userid': ''};
      angularForm.ipmi_userid.$setViewValue('admin');
      expect(angularForm.ipmi_address.$valid).toBeFalsy();
      expect(angularForm.$invalid).toBeTruthy();
    });
    it('sets the form from invalid to valid if ipmi_userid is filled in followed by ipmi_address', function() {
      $scope.hostModel = {'ipmi_address': '', 'ipmi_userid': ''};
      angularForm.ipmi_userid.$setViewValue('admin');
      expect(angularForm.ipmi_address.$valid).toBe(false);
      expect(angularForm.$invalid).toBe(true);
      angularForm.ipmi_address.$setViewValue('aaa');
      expect(angularForm.ipmi_address.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });
    it('sets the form to valid if ipmi_userid is filled in and ipmi_address is already filled in', function() {
      $scope.hostModel = {'ipmi_address': '', 'ipmi_userid': ''};
      angularForm.ipmi_address.$setViewValue('aaa');
      angularForm.ipmi_userid.$setViewValue('admin');
      expect(angularForm.ipmi_address.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });
    it('sets the form to valid if ipmi_userid is filled in and ipmi_address exists in the model', function() {
      $scope.hostModel = {'ipmi_address': 'aaa', 'ipmi_userid': ''};
      angularForm.ipmi_userid.$setViewValue('admin');
      expect(angularForm.ipmi_address.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });
    it('sets the form to invalid if ipmi_address and ipmi_userid exist in the model and ipmi_address is blanked out', function() {
      $scope.hostModel = {'ipmi_address': 'aaa', 'ipmi_userid': 'admin'};
      angularForm.ipmi_address.$setViewValue('');
      expect(angularForm.ipmi_address.$valid).toBeFalsy();
      expect(angularForm.$invalid).toBeTruthy();
    });
  });
});
