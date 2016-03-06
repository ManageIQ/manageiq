ManageIQ.angular.app.controller('pagingDivButtonGroupController', ['$scope', 'miqService', '$compile', function($scope, miqService, $compile) {
  var init = function() {
    saveButton();
    resetButton();
    cancelButton();

    $scope.saveable = miqService.saveable;
    $scope.disabledClick = miqService.disabledClick;
  }

  var saveButton = function() {
    var disabledSaveHtml = '<button name="button" id="save_disabled" type="submit" class="btn btn-primary btn-disabled" ' +
      'alt="Save changes" title="Save changes" ng-click="disabledClick($event)" style="cursor:not-allowed" ' +
      'ng-show="!newRecord && !saveable(angularForm)">Save</button>';
    var compiledDisabledSave = $compile(disabledSaveHtml)($scope);

    var enabledSaveHtml = '<button name="button" id="save_enabled" type="submit" class="btn btn-primary ng-hide" ' +
      'alt="Save changes" title="Save changes" ng-click="saveClicked($event, true)" ' +
      'ng-show="!newRecord && saveable(angularForm)">Save</button>';
    var compiledEnabledSave = $compile(enabledSaveHtml)($scope);

    if (angular.element(document.getElementById('save_disabled')).length == 0) {
      angular.element(document.getElementById('angular_paging_div_buttons')).append(compiledDisabledSave);
    }

    if (angular.element(document.getElementById('save_enabled')).length == 0) {
      angular.element(document.getElementById('angular_paging_div_buttons')).append(compiledEnabledSave);
    }
  }

  var resetButton = function() {
    var resetHtml = '<button name="button" id="reset_enabled_diabled" type="submit" ' +
      'class="btn btn-default btn-disabled" alt="Reset changes" title="Reset changes" ' +
      'ng-class="{\'btn-disabled\': angularForm.$pristine}" ng-click="resetClicked()" ' +
      'ng-disabled="angularForm.$pristine" ng-hide="newRecord" disabled="disabled">Reset</button>';
    var compiledReset = $compile(resetHtml)($scope);

    if (angular.element(document.getElementById('reset_enabled_diabled')).length == 0) {
      angular.element(document.getElementById('angular_paging_div_buttons')).append(compiledReset);
    }
  }

  var cancelButton = function() {
    var cancelHtml = '<button name="button" id="cancel_enabled" type="submit" class="btn btn-default" alt="Cancel" ' +
      'title="Cancel" ng-click="cancelClicked($event)">Cancel</button>';
    var compiledCancel = $compile(cancelHtml)($scope);

    if (angular.element(document.getElementById('cancel_enabled')).length == 0) {
      angular.element(document.getElementById('angular_paging_div_buttons')).append(compiledCancel);
    }
  }
  init();
}]);
