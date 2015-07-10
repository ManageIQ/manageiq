describe('update-drop-down-for-timer initialization', function() {
  var $scope, form;
  beforeEach(module('miqAngularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<select id="timer_typ" name="timer_typ" ng-model="scheduleModel.timer_typ"><option>Once</option><option>Weekly</option></select>' +
      '<select id="timer_value" name="timer_value" update-dropdown-for-timer dropdown-model="scheduleModel" timer-hide="timerTypeOnce" ng-model="scheduleModel.timer_value"><option value="0" label="Week">Week</option><option value="1" label="2 Weeks">2 Weeks</option>' +
      '</select>' +
      '</form>'
    );

    $scope.timer_items = [{text:'Week', value: '0'},
                          {text:'2 Weeks', value: '1'}];



    $scope.miqService = { miqFlashClear: function (){}};
    spyOn($scope.miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
  }));

  describe("When timer_value is not Once", function () {
    it('it attaches selectpicker classes to the timer_value dropdown', inject(function($timeout) {
      $scope.timerTypeOnce = false;
      form.timer_value.$setViewValue('0');
      $scope.scheduleModel.timer_value = '0';
      $timeout.flush();
      expect(elem[0][2].className).toMatch(/selectpicker/);
      expect(elem[0][2].className).toMatch(/btn-default/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      expect($scope.angularForm.timer_value.$viewValue).toBe("0");
    }));
  });

  describe("When timerTypeOnce is true", function () {
    it('it hides the timer_value dropdown', inject(function($timeout) {
      $scope.timerTypeOnce = true;
      $scope.timer_items = [];
      $timeout.flush();
      expect(elem[0][2].parentElement.attributes['style']['value']).toMatch(/display: none/);
      expect($scope.angularForm.timer_value.$viewValue).toBeUndefined();
    }));
  });
});
