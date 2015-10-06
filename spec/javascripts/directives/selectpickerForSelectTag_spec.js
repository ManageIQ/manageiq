describe('selectpicker-for-select-tag initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ.angularApplication'));
  beforeEach(inject(function($compile, $rootScope, miqService) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
        '<select id="action_typ" name="action_typ" selectpicker-for-select-tag ng-model="scheduleModel.action_typ"><option>Mustard</option><option>Ketchup</option><option>Relish</option></select>' +
      '</form>'
    );

    spyOn(miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe('selectpicker-for-select-tag', function() {
    it('attaches selectpicker classes', function() {
      form.action_typ.$setViewValue('Mustard');
      expect(elem[0][0].className).toMatch(/bs-select-hidden/);
      expect(elem[0][1].className).toMatch(/dropdown-toggle/);
    });
  });
});
