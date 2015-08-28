describe('autofocus initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ.angularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<input auto-focus type="text" ng-model="emsCommonModel" name="name"/>' +
      '<input type="text" ng-model="emsCommonModel" name="type"/>' +
      '</form>'
    );
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
    $scope.afterGet = false;
  }));

  describe('autofocus specs', function() {
    it('should set focus on the name field', inject(function($timeout) {
      spyOn(elem[0][0], 'focus');
      form.name.$setViewValue('amazon');
      form.type.$setViewValue('ec2');
      $scope.afterGet = true;
      $timeout.flush();
      expect((elem[0][0]).focus).toHaveBeenCalled();
    }));
    it('should not set the focus on type field', inject(function($timeout) {
      spyOn(elem[0][1], 'focus');
      form.name.$setViewValue('amazon');
      form.type.$setViewValue('ec2');
      $scope.afterGet = true;
      $timeout.flush();
      expect((elem[0][1]).focus).not.toHaveBeenCalled();
    }));
  });
});
