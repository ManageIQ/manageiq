describe('checkchange initialization', function() {
  var $scope, form;
  beforeEach(module('miqAngularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<input checkchange type="text" ng-model="repo.path" name="repo_path"/>' +
      '</form>'
    );
    $scope.repoModel = {repo_path : "//a/a2"};
    $scope.modelCopy = {repo_path : "//a/a2"};
    $scope.model = "repoModel";
    $scope.miqService = { miqFlashClear: function (){}};
    spyOn($scope.miqService, 'miqFlashClear');
    $compile(element)($scope);
    $scope.$digest();
    form = $scope.angularForm;
  }));

  describe('checkchange', function() {
    it('should set value and form to a non-pristine state when a different value is detected', function() {
      form.repo_path.$setViewValue('//storage/b1');
      expect($scope.angularForm['repo_path'].$untouched).toBe(false);
      expect($scope.angularForm.$pristine).toBe(false);
    });
    it('should set value and form to a pristine state when same value is detected', function() {
      form.repo_path.$setViewValue('//a/a2');
      expect(form.repo_path.$pristine).toBe(true);
      expect(form.$pristine).toBe(true);
    });
  });
});
