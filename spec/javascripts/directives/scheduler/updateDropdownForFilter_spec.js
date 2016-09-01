describe('update-drop-down-for-filter initialization', function() {
  var $scope, $timeout;
  var elem, form;

  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope, _$timeout_) {
    $scope = $rootScope;
    $timeout = _$timeout_;

    var element = angular.element([
      '<form name="angularForm">',
      '  <select id="filter_typ" name="filter_typ" ng-model="scheduleModel.filter_typ">',
      '    <option>All VMs</option>',
      '    <option>Ketchup</option>',
      '    <option>Relish</option>',
      '  </select>',
      '  ',
      '  <select id="filter_value" name="filter_value" update-dropdown-for-filter dropdown-model="scheduleModel" dropdown-list="filterList" filter-hide="filterValuesEmpty" ng-model="scheduleModel.filter_value" ng-options="item.text for item in filterList track by item.text">',
      '    <option disabled="" value="" selected="selected">Choose</option>',
      '  </select>',
      '</form>',
    ].join("\n"));

    $scope.filterList = [{text:'Mustard',
                          value: 'Mustard'},
                         {text:'Ketchup',
                          value: 'Ketchup'},
                         {text:'Relish',
                          value: 'Relish'}];

    $scope.filterValuesEmpty = false;

    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe("When filter_value is blank", function() {
    it('it attaches an error class to selectpicker', function() {
      form.filter_value.$setViewValue('');
      $timeout.flush();

      var bsSelect = elem.children('.bootstrap-select');
      var bsButton = bsSelect.children('.btn.dropdown-toggle');

      expect(bsButton.hasClass('btn-red-border')).toBe(true);
      expect(bsSelect.css('display')).not.toBe('none');
      expect(form.filter_value.$viewValue).toBe("");
      expect(bsButton.prop('title')).toBe("Choose");
    });
  });

  describe("When filter_value is not blank", function() {
    it('it clears the error class previously attached to selectpicker', function() {
      form.filter_value.$setViewValue('Ketchup');
      $timeout.flush();

      var bsSelect = elem.children('.bootstrap-select');
      var bsButton = bsSelect.children('.btn.dropdown-toggle');
      var origSelect = bsSelect.children('select');

      var optionMustard = origSelect.find('option[value="Mustard"]');
      var optionKetchup = origSelect.find('option[value="Ketchup"]');

      expect(bsButton.hasClass('btn-default')).toBe(true);
      expect(bsButton.hasClass('btn-red-border')).toBe(false);
      expect(bsSelect.css('display')).not.toBe('none');
      expect(optionKetchup.prop('selected')).toBe(true);
      expect(optionMustard.prop('selected')).toBe(false);
      expect(bsButton.prop('title')).toMatch(/Ketchup/);
    });
  });

  describe("When filterValuesEmpty is true", function() {
    it('it attaches an error class to selectpicker', function() {
      $scope.filterValuesEmpty = true;
      form.filter_typ.$setViewValue('all');
      $timeout.flush();

      var bsSelect = elem.children('.bootstrap-select');

      expect(bsSelect.css('display')).toBe('none');
      expect(form.filter_value.$viewValue).toBeUndefined();
    });
  });
});
