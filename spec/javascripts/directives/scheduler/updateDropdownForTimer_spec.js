describe('update-drop-down-for-timer initialization', function() {
  var $scope, form, model;
  beforeEach(module('ManageIQ.angularApplication'));
  beforeEach(inject(function($compile, $rootScope) {
    $scope = $rootScope;
    var element = angular.element(
      '<form name="angularForm">' +
      '<select id="timer_typ" name="timer_typ" ng-model="scheduleModel.timer_typ"><option>Once</option><option>Weekly</option></select>' +
      '<select id="timer_value" name="timer_value" update-dropdown-for-timer dropdown-model="scheduleModel" timer-hide="timerTypeOnce" ng-model="scheduleModel.timer_value" ng-options="timerItem.value as timerItem.text for timerItem in timer_items"></select>' +
      '</form>'
    );

    $scope.timer_items = [{text:'Week', value: 0},
                          {text:'2 Weeks', value: 1}];

    $scope.miqService = { miqFlashClear: function (){} };
    $scope.scheduleModel = {};
    spyOn($scope.miqService, 'miqFlashClear');
    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
    model = $scope.scheduleModel;
  }));

  describe("When timer_value is not Once", function () {
    it('it attaches selectpicker classes to the timer_value dropdown', inject(function($timeout) {
      $scope.timerTypeOnce = false;
      model.timer_value = 0;
      $timeout.flush();
      expect(elem[0][2].className).toMatch(/selectpicker/);
      expect(elem[0][2].className).toMatch(/btn-default/);
      expect(elem[0][2].parentElement.attributes['style']['value']).not.toMatch(/display: none/);
      expect(form.timer_value.$viewValue).toBe(0);
      expect(model.timer_value).toBe(0);
    }));
  });

  describe("When timerTypeOnce is true", function () {
    it('it hides the timer_value dropdown', inject(function($timeout) {
      $scope.timerTypeOnce = true;
      $scope.timer_items = [];
      $timeout.flush();
      expect(elem[0][2].parentElement.attributes['style']['value']).toMatch(/display: none/);
      expect(form.timer_value.$viewValue).toBeUndefined();
    }));
  });
});
