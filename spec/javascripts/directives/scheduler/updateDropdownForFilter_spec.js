describe('update-drop-down-for-filter initialization', function() {
  var $scope, form;
  beforeEach(module('ManageIQ.angularApplication'));
  beforeEach(inject(function($compile, $rootScope, $timeout, miqService) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<select id="filter_typ" name="filter_typ" ng-model="scheduleModel.filter_typ"><option>All VMs</option><option>Ketchup</option><option>Relish</option></select>' +
      '<select id="filter_value" name="filter_value" update-dropdown-for-filter dropdown-model="scheduleModel" dropdown-list="filterList" filter-hide="filterValuesEmpty" ng-model="scheduleModel.filter_value" ng-options="item.text for item in filterList track by item.text">' +
	  '<option disabled="" value="" class="" selected="selected">Choose</option>' +	
      '</select>' +
      '</form>'
    );

    $scope.filterList = [{text:'Mustard',
                         value: 'Mustard'},
                        {text:'Ketchup',
                          value: 'Ketchup'},
                        {text:'Relish',
                          value: 'Relish'}];

    $scope.filterValuesEmpty = false;

    spyOn(miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe("When filter_value is blank", function () {
    it('it attaches an error class to selectpicker', inject(function($timeout) {
      form.filter_value.$setViewValue('');
      $timeout.flush();
      expect(elem[0][1].className).toMatch(/bs-select-hidden/);
      expect(elem[0][2].className).toMatch(/btn-red-border/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      expect($scope.angularForm.filter_value.$viewValue).toBe("");
      expect(elem[0][2].attributes['title']['value']).toBe("Choose");
    }));
  });

  describe("When filter_value is not blank", function () {
    it('it clears the error class previously attached to selectpicker', inject(function($timeout) {
      form.filter_value.$setViewValue('Ketchup');
      $timeout.flush();
      expect(elem[0][1].className).toMatch(/bs-select-hidden/);
      expect(elem[0][2].className).toMatch(/btn-default/);
      expect(elem[0][2].className).not.toMatch(/btn-red-border/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      optionMustard = elem[0][1][1];
      optionKetchup = elem[0][1][2];
      expect(optionKetchup).toBeSelected();
      expect(optionMustard).not.toBeSelected();
      expect(elem[0][2].attributes['title']['value']).toMatch(/Ketchup/);
    }));
  });

  describe("When filterValuesEmpty is true", function () {
    it('it attaches an error class to selectpicker', inject(function($timeout) {
      $scope.filterValuesEmpty = true;
      form.filter_typ.$setViewValue('all');
      $timeout.flush();
      expect(elem[0][2].parentElement.attributes['style']['value']).toMatch(/display: none/);
      expect($scope.angularForm.filter_value.$viewValue).toBeUndefined();
    }));
  });
});
