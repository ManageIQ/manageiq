describe('detectSpaces initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.model = "hostModel";
    var element = angular.element(
      '<form name="angularForm">' +
      '<input type="text" ng-trim=false detect-spaces ng-model="emsCommonModel.hostname" name="hostname"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;
  }));

  describe('detect-spaces', function() {
    it('sets the form to invalid if hostname has spaces in it', function() {
      angularForm.hostname.$setViewValue('test. com');
      expect(angularForm.hostname.$error.detectedSpaces).toBeDefined();
      expect(angularForm.hostname.$valid).toBeFalsy();
      expect(angularForm.$invalid).toBeTruthy();
    });

    it('sets the form to valid if hostname does not have spaces in it', function() {
      angularForm.hostname.$setViewValue('test.com');
      expect(angularForm.hostname.$error.detectedSpaces).not.toBeDefined();
      expect(angularForm.hostname.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });
  });
});
