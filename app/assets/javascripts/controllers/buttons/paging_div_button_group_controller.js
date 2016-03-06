ManageIQ.angular.app.controller('pagingDivButtonGroupController', ['$scope', 'miqService', '$compile', '$attrs', function($scope, miqService, $compile, $attrs) {
  var init = function() {
    saveButton();
    resetButton();
    cancelButton();

    $scope.saveable = miqService.saveable;
    $scope.disabledClick = miqService.disabledClick;
  }

  var saveButton = function() {
    var disabledSaveHtml = sprintf('<button name="button" id="save_disabled" type="submit" class="btn btn-primary btn-disabled" ' +
      'alt=%s title=%s ng-click="disabledClick($event)" style="cursor:not-allowed" ' +
      'ng-show="!newRecord && !saveable(angularForm)">%s</button>', __("Save changes"), __("Save changes"), __("Save"));
    var compiledDisabledSave = $compile(disabledSaveHtml)($scope);

    var enabledSaveHtml = sprintf('<button name="button" id="save_enabled" type="submit" class="btn btn-primary ng-hide" ' +
      'alt=%s title=%s ng-click="saveClicked($event, true)" ' +
      'ng-show="!newRecord && saveable(angularForm)">%s</button>', __("Save changes"), __("Save changes"), __("Save"));
    var compiledEnabledSave = $compile(enabledSaveHtml)($scope);

    if (angular.element(document.getElementById('save_disabled')).length == 0) {
      angular.element(document.getElementById($attrs.pagingDivButtonsId)).append(compiledDisabledSave);
    }

    if (angular.element(document.getElementById('save_enabled')).length == 0) {
      angular.element(document.getElementById($attrs.pagingDivButtonsId)).append(compiledEnabledSave);
    }
  }

  var resetButton = function() {
    var resetHtml = sprintf('<button name="button" id="reset_enabled_diabled" type="submit" ' +
      'class="btn btn-default btn-disabled" alt=%s title=%s ' +
      'ng-class="{\'btn-disabled\': angularForm.$pristine}" ng-click="resetClicked()" ' +
      'ng-disabled="angularForm.$pristine" ng-hide="newRecord" disabled="disabled">%s</button>', __("Reset changes"), __("Reset changes"), __("Reset"));
    var compiledReset = $compile(resetHtml)($scope);

    if (angular.element(document.getElementById('reset_enabled_diabled')).length == 0) {
      angular.element(document.getElementById($attrs.pagingDivButtonsId)).append(compiledReset);
    }
  }

  var cancelButton = function() {
    var cancelHtml = sprintf('<button name="button" id="cancel_enabled" type="submit" class="btn btn-default" alt=%s ' +
      'title=%s ng-click="cancelClicked($event)">%s</button>', __("Cancel"), __("Cancel"), __("Cancel"));
    var compiledCancel = $compile(cancelHtml)($scope);

    if (angular.element(document.getElementById('cancel_enabled')).length == 0) {
      angular.element(document.getElementById($attrs.pagingDivButtonsId)).append(compiledCancel);
    }
  }
  init();
}]);
