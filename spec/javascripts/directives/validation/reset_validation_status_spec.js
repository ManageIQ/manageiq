describe('resetValidationStatus initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.model = "emsCommonModel";
    var element = angular.element(
      '<form name="angularForm">' +
      '<input type="text" error-on-tab="default"/>' +
      '<input type="text" reset-validation-status="default_auth_status" prefix="default" ng-model="emsCommonModel.hostname" name="hostname"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    elem = $compile(element)($rootScope);
    angularForm = $scope.angularForm;
  }));

  describe('reset-validation-status', function() {
    it('set validation required icon when hostname value changes', inject(function($rootScope, $timeout) {
      $scope.model = {};
      $scope.postValidationModel = {};
      $scope.checkAuthentication = true;
      $scope.postValidationModel['default'] = {hostname: "abc"};
      $scope.model = 'emsCommonModel';
      $scope['emsCommonModel'] = {hostname: "xyz"};
      $timeout.flush();
      expect(elem[0][0].className).toEqual("fa fa-exclamation-circle");
    }));
  });

  describe('reset-validation-status', function() {
    it('clear validation required icon when hostname value is restored to original', inject(function($rootScope, $timeout) {
      $scope.model = {};
      $scope.postValidationModel = {};
      $scope.checkAuthentication = true;
      $scope.postValidationModel['default'] = {hostname: "abc"};
      $scope.model = 'emsCommonModel';
      $scope['emsCommonModel'] = {hostname: "abc"};
      $timeout.flush();
      expect(elem[0][0].className).toEqual("");
    }));
  });
});
