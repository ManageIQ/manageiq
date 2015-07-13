describe('miqrequired initialization', function() {
  var $scope, form;
  beforeEach(module('miqAngularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="form">' +
      '<input miqrequired type="text" ng-model="repo.name" name="repo_name"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    form = $scope.form;
  }));

  describe('miqrequired', function() {
    it('should set form to invalid if value is blanked out', function() {
      form.repo_name.$setViewValue('');
      expect(form.repo_name.$valid).toBe(false);
      expect(form.$invalid).toBe(true);
    });
    it('should set form to valid if a non-blank value exists', function() {
      form.repo_name.$setViewValue('bbb');
      expect(form.repo_name.$valid).toBe(true);
      expect(form.$invalid).toBe(false);
    });
  });
});

