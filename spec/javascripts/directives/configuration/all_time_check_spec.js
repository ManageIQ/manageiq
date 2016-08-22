describe('allTimeCheck initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    $scope.timeProfileModel = {};
    $scope.timeProfileModel.dayValues = _.times(7, _.constant(false));
    var element = angular.element(
      '<form name="angularForm">' +
      '<input type="checkbox" name="dayValue" ng-model="timeProfileModel.dayValues[0]" time-type="day" all-time-check="0"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;
  }));

  describe('allTimeCheck', function() {
    it('sets timeProfileModel.all_days to false if the selected day checkbox is false', function() {
      $scope.timeProfileModel.dayValues = _.times(7, _.constant(true));
      angularForm.dayValue.$setViewValue(false);
      expect($scope.timeProfileModel.all_days).toBeFalsy();
    });

    it('sets timeProfileModel.all_days to true if the selected day checkbox is true', function() {
      $scope.timeProfileModel.dayValues = [false, true, true, true, true, true, true];
      angularForm.dayValue.$setViewValue(true);
      expect($scope.timeProfileModel.all_days).toBeTruthy();
    });

    it('sets timeProfileModel.all_days to undefined if the selected day checkbox is true, but one other day is false', function() {
      $scope.timeProfileModel.dayValues = [false, false, true, true, true, true, true];
      angularForm.dayValue.$setViewValue(true);
      expect($scope.timeProfileModel.all_days).toBeUndefined();
    });
  });
});
