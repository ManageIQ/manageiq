describe('pagingDivButtonGroupController', function() {
  var $scope, $controller, miqService, $compile;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _miqService_, _$compile_) {
    miqService = _miqService_;
    $scope = $rootScope.$new();
    $compile = _$compile_;

    $scope.newRecord = false;

    $scope.model = "myModel";
    var element = angular.element(
      '<form name="angularForm">' +
      '<input type="text" ng-model="myModel.userid" name="userid"/>' +
      '</form>'
    );
    $compile(element)($scope);
    $scope.$digest();
    angularForm = $scope.angularForm;

    paging_div = angular.element('<div id="angular_paging_div_buttons"></div>');
    angular.element(document.body).append(paging_div);

    $controller = _$controller_('pagingDivButtonGroupController',
      {$scope:     $scope,
       miqService: miqService,
       $compile:   $compile,
       $attrs:     {'pagingDivButtonsId': 'angular_paging_div_buttons'}});
  }));

  afterEach(function(){
    paging_div.remove();
    paging_div = null;
  });

  describe('when form is pristine', function() {
    it('it displays a disabled Save button and a disabled Reset button', function() {
      expect(paging_div[0].childNodes[0].className).not.toContain('ng-hide');
      expect(paging_div[0].childNodes[1].className).toContain('ng-hide');
      expect(paging_div[0].childNodes[2].outerHTML).toContain('disabled="disabled"');
    });
  });

  describe('when form is dirty', function() {
    it('it displays an enabled Save button and an enabled Reset button', function() {
      angularForm.userid.$setViewValue('admin');
      expect(paging_div[0].childNodes[0].className).toContain('ng-hide');
      expect(paging_div[0].childNodes[1].className).not.toContain('ng-hide');
      expect(paging_div[0].childNodes[2].outerHTML).not.toContain('disabled="disabled"');
    });
  });
});
