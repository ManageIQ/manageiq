describe('selectpicker-for-select-tag initialization', function() {
  var $scope, form;
  beforeEach(module('miqAngularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
        '<select id="action_typ" name="action_typ" selectpicker-for-select-tag ng-model="scheduleModel.action_typ"><option>Mustard</option><option>Ketchup</option><option>Relish</option></select>' +
      '</form>'
    );

    $scope.miqService = { miqFlashClear: function (){}};
    spyOn($scope.miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe('selectpicker-for-select-tag', function() {
    it('attaches selectpicker classes', function() {
      form.action_typ.$setViewValue('Mustard');
      className = elem[0][1].className;
      expect(className).toMatch(/selectpicker/);
      expect(className).toMatch(/dropdown-toggle/);
    });
  });
});
