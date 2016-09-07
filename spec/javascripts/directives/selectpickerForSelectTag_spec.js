describe('selectpicker-for-select-tag initialization', function() {
  var $scope;
  var elem, form;

  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;

    var element = angular.element([
      '<form name="angularForm">',
      '  <select id="action_typ" name="action_typ" selectpicker-for-select-tag ng-model="scheduleModel.action_typ">',
      '    <option>Mustard</option>',
      '    <option>Ketchup</option>',
      '    <option>Relish</option>',
      '  </select>',
      '</form>',
    ].join("\n"));

    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe('selectpicker-for-select-tag', function() {
    it('attaches selectpicker classes', function() {
      form.action_typ.$setViewValue('Mustard');

      var bsSelect = elem.children('.bootstrap-select');
      var bsButton = bsSelect.children('.btn.dropdown-toggle');

      expect(bsSelect).toBeDefined();
      expect(bsButton).toBeDefined();
    });
  });
});
