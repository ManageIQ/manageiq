describe('checkpath initialization', function() {
  var $scope, form;
  beforeEach(module('cfmeAngularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="form">' +
      '<input checkpath type="text" ng-model="repo.path" name="repo_path"/>' +
      '</form>'
    );
    $scope.miqService = { miqFlash: function (type, msg){}};
    spyOn($scope.miqService, 'miqFlash');
    $compile(element)($scope);
    $scope.$digest();
    form = $scope.form;
  }));

  describe('checkpath', function() {
    it('should pass with valid UNC path of type NAS', function() {
      form.repo_path.$setViewValue('//storage/b');
      expect(form.repo_path.$valid).toBeTruthy();
      expect($scope.path_type).toBe("NAS");
    });

    it('should pass with valid UNC path of type VMFS', function() {
      form.repo_path.$setViewValue('[C][D]');
      expect(form.repo_path.$valid).toBeTruthy();
      expect($scope.path_type).toBe("VMFS");
    });

    it('should not pass with invalid UNC path', function() {
      form.repo_path.$setViewValue('a');
      expect(form.repo_path.$valid).toBeFalsy();
    });
  });
});
