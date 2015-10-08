describe('requiredIfExisted initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ.angularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.model = "hostModel";
    var element = angular.element(
      '<form name="angularForm">' +
      '<input required-if-existed="default_password" required-depends-on="hostModel.default_password" type="text" ng-model="hostModel.default_userid" name="default_userid"/>' +
      '<input type="password" ng-model="hostModel.default_password" name="default_password"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;
  }));

  describe('required-if-existed', function() {
    it('should set form to invalid if userid is blanked out', function() {
      $scope.hostModel = {'default_userid': 'abc', 'default_password': 'abc'};
      $scope.modelCopy = angular.copy( $scope.hostModel );
      angularForm.default_userid.$setViewValue('');
      expect(angularForm.default_userid.$valid).toBe(false);
      expect(angularForm.$invalid).toBe(true);
    });
    it('should set form to valid if userid is changed', function() {
      angularForm.default_userid.$setViewValue('aaa');
      expect(angularForm.default_userid.$valid).toBe(true);
      expect(angularForm.$invalid).toBe(false);
    });
    it('should set form to valid if userid is unchanged', function() {
      expect(angularForm.default_userid.$valid).toBe(true);
      expect(angularForm.$invalid).toBe(false);
    });
    it('should set form to invalid if only password was filled in', function() {
      $scope.hostModel = {'default_userid': '', 'default_password': ''};
      $scope.modelCopy = angular.copy( $scope.hostModel );
      angularForm.default_password.$setViewValue('abc');
      expect(angularForm.default_userid.$valid).toBe(false);
      expect(angularForm.$invalid).toBe(true);
    });
    it('should set form from invalid to valid if password (only field filled in) that was filled in previously is blanked out', function() {
      $scope.hostModel = {'default_userid': '', 'default_password': ''};
      $scope.modelCopy = angular.copy( $scope.hostModel );
      angularForm.default_password.$setViewValue('abc');
      expect(angularForm.default_userid.$valid).toBe(false);
      expect(angularForm.$invalid).toBe(true);
      angularForm.default_password.$setViewValue('');
      expect(angularForm.default_userid.$valid).toBe(true);
      expect(angularForm.$invalid).toBe(false);
    });
  });
});
