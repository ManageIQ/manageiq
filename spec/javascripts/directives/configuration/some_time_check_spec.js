describe('someTimeCheck initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.timeProfileModel = {};
    var element = angular.element(
      '<form name="angularForm">' +
      '<input type="checkbox" name="some_days_checked" ng-model="timeProfileModel.some_days_checked" time-type="day" some-time-check/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;
  }));

  describe('someTimeCheck', function() {
    it('sets someTimeCheck error if none of the days are checked', function() {
      $scope.timeProfileModel.dayValues = _.times(7, _.constant(false));
      angularForm.some_days_checked.$setViewValue('');
      expect(angularForm.some_days_checked.$error.someTimeCheck).toBeDefined();
      expect(angularForm.some_days_checked.$valid).toBeFalsy();
      expect(angularForm.$invalid).toBeTruthy();
    });

    it('does not set someTimeCheck error if all of the days are checked', function() {
      $scope.timeProfileModel.dayValues = _.times(7, _.constant(true));
      angularForm.some_days_checked.$setViewValue('');
      expect(angularForm.some_days_checked.$error.someTimeCheck).toBeUndefined();
      expect(angularForm.some_days_checked.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });

    it('does not set someTimeCheck error if some of the days are checked', function() {
      $scope.timeProfileModel.dayValues =[false, false, false, false, false, true, false];
      angularForm.some_days_checked.$setViewValue('');
      expect(angularForm.some_days_checked.$error.someTimeCheck).toBeUndefined();
      expect(angularForm.some_days_checked.$valid).toBeTruthy();
      expect(angularForm.$invalid).toBeFalsy();
    });
  });
});
