describe('update-drop-down-for-filter initialization', function() {
  var $scope, form;
  beforeEach(module('miqAngularApplication'));
  beforeEach(inject(function($compile, $rootScope, $timeout) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<select id="filter_typ" name="filter_typ" ng-model="scheduleModel.filter_typ"><option>All VMs</option><option>Ketchup</option><option>Relish</option></select>' +
      '<select id="filter_value" name="filter_value" update-dropdown-for-filter dropdown-model="scheduleModel" dropdown-list="filterList" filter-hide="filterValuesEmpty" ng-model="scheduleModel.filter_value"><option value="" label="Choose">Choose</option><option value="0" label="Mustard">Mustard</option><option value="1" label="Ketchup">Ketchup</option><option value="2" label="Relish">Relish</option>' +
      '</select>' +
      '</form>'
    );

    $scope.filterList = [{text:'Mustard',
                         value: '0'},
                        {text:'Ketchup',
                          value: '1'},
                        {text:'Relish',
                          value: '2'}];

    $scope.filterValuesEmpty = false;

    $scope.miqService = { miqFlashClear: function (){}};
    spyOn($scope.miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe("When filter_value is blank", function () {
    it('it attaches an error class to selectpicker', inject(function($timeout) {
      form.filter_value.$setViewValue('');
      $timeout.flush();
      expect(elem[0][2].className).toMatch(/selectpicker/);
      expect(elem[0][2].className).toMatch(/btn-red-border/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      expect($scope.angularForm.filter_value.$viewValue).toBe("");
      expect(elem[0][2].attributes['title']['value']).toBe("Choose");
    }));
  });

  describe("When filter_value is not blank", function () {
    it('it attaches an error class to selectpicker', inject(function($timeout) {
      form.filter_value.$setViewValue('1');
      $timeout.flush();
      expect(elem[0][2].className).toMatch(/selectpicker/);
      expect(elem[0][2].className).toMatch(/btn-default/);
      expect(elem[0][2].className).not.toMatch(/btn-red-border/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      expect($scope.angularForm.filter_value.$viewValue).toBe("1");
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
