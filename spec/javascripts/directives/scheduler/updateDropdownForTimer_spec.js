describe('update-drop-down-for-timer initialization', function() {
  var $scope, $timeout;
  var elem, form, model;

  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope, _$timeout_) {
    $scope = $rootScope;
    $timeout = _$timeout_;

    var element = angular.element([
      '<form name="angularForm">',
      '  <select id="timer_typ" name="timer_typ" ng-model="scheduleModel.timer_typ">',
      '    <option>Once</option>',
      '    <option>Weekly</option>',
      '  </select>',
      '  ',
      '  <select id="timer_value" name="timer_value" update-dropdown-for-timer dropdown-model="scheduleModel" timer-hide="timerTypeOnce" ng-model="scheduleModel.timer_value" ng-options="timerItem.value as timerItem.text for timerItem in timer_items"></select>',
      '</form>',
    ].join("\n"));

    $scope.timer_items = [{text: 'Week', value: 0},
                          {text: '2 Weeks', value: 1}];
    $scope.scheduleModel = {};

    elem = $compile(element)($rootScope);
    form = $scope.angularForm;
    model = $scope.scheduleModel;
  }));

  describe("When timer_value is not Once", function() {
    it('it attaches selectpicker classes to the timer_value dropdown', function() {
      $scope.timerTypeOnce = false;
      model.timer_value = 0;
      $timeout.flush();

      var bsSelect = elem.children('.bootstrap-select');
      var bsButton = bsSelect.children('.btn.dropdown-toggle');

      expect(bsButton.hasClass('btn-default')).toBe(true);
      expect(bsSelect.css('display')).not.toBe('none');
      expect(form.timer_value.$viewValue).toBe(0);
      expect(model.timer_value).toBe(0);
    });
  });

  describe("When timerTypeOnce is true", function() {
    it('it hides the timer_value dropdown', function() {
      $scope.timerTypeOnce = true;
      $scope.timer_items = [];
      $timeout.flush();

      var bsSelect = elem.children('.bootstrap-select');
      var bsButton = bsSelect.children('.btn.dropdown-toggle');

      expect(bsSelect.css('display')).toBe('none');
      expect(form.timer_value.$viewValue).toBeUndefined();
    });
  });
});
