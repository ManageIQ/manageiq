ManageIQ.angular.app.controller('pagingDivButtonGroupController', ['$scope', 'miqService', '$compile', '$attrs', '$timeout', function($scope, miqService, $compile, $attrs, $timeout) {
  var init = function() {
    $scope.addBtnText = __("Add");
    $scope.saveBtnText = __("Save");
    $scope.saveAltText = __("Save Changes");
    $scope.submitBtnText = __("Submit");
    $scope.submitAltText = __("Submit Changes");
    $scope.resetBtnText = __("Reset");
    $scope.resetAltText = __("Reset Changes");
    $scope.cancelBtnText = __("Cancel");

    if ($attrs.pagingDivButtonsType == "Add") {
      saveButton('Add');
      cancelButton();
    } else if ($attrs.pagingDivButtonsType == "Submit") {
      saveButton('Submit', $attrs.pagingDivButtonsStateEnabled);
      cancelButton();
    } else {
      saveButton();
      resetButton();
      cancelButton();
    }

    $scope.saveable = miqService.saveable;
    $scope.disabledClick = miqService.disabledClick;
  }

  var saveButton = function(type, buttonStateEnabled) {
    $scope.altText =  $scope.saveAltText;
    $scope.btnText = $scope.saveBtnText;
    $scope.btnClick = $scope.saveClicked;

    if(type == "Add") {
      $scope.altText =  $scope.addBtnText;
      $scope.btnText = $scope.addBtnText;
      $scope.btnClick = $scope.addClicked;
    } else if(type == "Submit") {
      $scope.altText =  $scope.submitAltText;
      $scope.btnText = $scope.submitBtnText;
      $scope.btnClick = $scope.submitClicked;
    }

    if (buttonStateEnabled) {
      var enabledSaveHtml = '<button name="button" id="save_enabled" type="submit" class="btn btn-primary" ' +
        'alt={{altText}} title={{altText}} ng-click="btnClick($event, true)">{{btnText}}</button>';
      var compiledEnabledSave = $compile(enabledSaveHtml)($scope);

      $timeout(function () {
        if (!miqDomElementExists('save_enabled')) {
          $('#' + $attrs.pagingDivButtonsId).append(compiledEnabledSave);
        }
      });
    } else {
      var disabledSaveHtml = '<button name="button" id="save_disabled" type="submit" class="btn btn-primary disabled" ' +
        'alt={{altText}} title={{altText}} ng-click="disabledClick($event)" ' +
        'ng-show="!newRecord && !saveable(angularForm)">{{btnText}}</button>';
      var compiledDisabledSave = $compile(disabledSaveHtml)($scope);

      var enabledSaveHtml = '<button name="button" id="save_enabled" type="submit" class="btn btn-primary ng-hide" ' +
        'alt={{altText}} title={{altText}} ng-click="btnClick($event, true)" ' +
        'ng-show="!newRecord && saveable(angularForm)">{{btnText}}</button>';
      var compiledEnabledSave = $compile(enabledSaveHtml)($scope);

      $timeout(function () {
        if (!miqDomElementExists('save_disabled')) {
          $('#' + $attrs.pagingDivButtonsId).append(compiledDisabledSave);
        }

        if (!miqDomElementExists('save_enabled')) {
          $('#' + $attrs.pagingDivButtonsId).append(compiledEnabledSave);
        }
      });
    }
  };

  var resetButton = function() {
    var resetHtml = '<button name="button" id="reset_enabled_disabled" type="submit" ' +
      'class="btn btn-default disabled" alt={{resetAltText}} title={{resetAltText}} ' +
      'ng-class="{ disabled: angularForm.$pristine }" ng-click="resetClicked()" ' +
      'ng-disabled="angularForm.$pristine" ng-hide="newRecord" disabled="disabled">{{resetBtnText}}</button>';
    var compiledReset = $compile(resetHtml)($scope);

    $timeout(function () {
      if (!miqDomElementExists('reset_enabled_disabled')) {
        $('#' + $attrs.pagingDivButtonsId).append(compiledReset);
      }
    });
  };

  var cancelButton = function() {
    var cancelHtml = '<button name="button" id="cancel_enabled" type="submit" class="btn btn-default" alt={{cancelBtnText}} ' +
      'title={{cancelBtnText}} ng-click="cancelClicked($event)">{{cancelBtnText}}</button>';
    var compiledCancel = $compile(cancelHtml)($scope);

    $timeout(function () {
      if (!miqDomElementExists('cancel_enabled')) {
        $('#' + $attrs.pagingDivButtonsId).append(compiledCancel);
      }
    });
  };
  init();
}]);
