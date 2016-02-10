describe('checkPath initialization', function() {
  var $scope;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope, miqService) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<input check-path type="text" ng-model="repo.path" name="repo_path"/>' +
      '</form>'
    );
    spyOn(miqService, 'miqFlash');
    $compile(element)($scope);
    $scope.$digest();
  }));

  describe('checkPath', function() {
    it('returns true for a valid UNC path of type NAS', function() {
      $scope.angularForm.repo_path.$setViewValue('//storage/b');
      expect($scope.angularForm.repo_path.$valid).toBeTruthy();
      expect($scope.path_type).toBe("NAS");
    });

    it('returns true for a valid UNC path of type VMFS', function() {
      $scope.angularForm.repo_path.$setViewValue('[C][D]');
      expect($scope.angularForm.repo_path.$valid).toBeTruthy();
      expect($scope.path_type).toBe("VMFS");
    });

    it('returns false for an invalid UNC path', function() {
      $scope.angularForm.repo_path.$setViewValue('a');
      expect($scope.angularForm.repo_path.$valid).toBeFalsy();
    });
  });
});
