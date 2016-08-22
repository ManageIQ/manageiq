ManageIQ.angular.app.controller('timeProfileFormController', ['$http', '$scope', 'timeProfileFormId', 'miqService', function($http, $scope, timeProfileFormId, miqService) {
  var init = function() {
    $scope.timeProfileModel = {
      description: '',
      admin_user: false,
      restricted_time_profile: false,
      profile_type: '',
      profile_tz: '',
      rollup_daily: false,
      all_days: false,
      days: [],
      dayValues: [],
      hours: [],
      hourValuesAMFirstHalf: [],
      hourValuesAMSecondHalf: [],
      hourValuesPMFirstHalf: [],
      hourValuesPMSecondHalf: [],
      hourValues: [],
      some_days_checked: true,
      some_hours_checked: true,
    };
    $scope.dayNames = [__("Sunday"), __("Monday"), __("Tuesday"), __("Wednesday"), __("Thursday"), __("Friday"), __("Saturday")];
    $scope.hourNamesFirstHalf = [__("12-1"), __("1-2"), __("2-3"), __("3-4"), __("4-5"), __("5-6")];
    $scope.hourNamesSecondHalf = [__("6-7"), __("7-8"), __("8-9"), __("9-10"), __("10-11"), __("11-12")];
    $scope.formId = timeProfileFormId;
    $scope.afterGet = false;
    $scope.modelCopy = angular.copy( $scope.timeProfileModel );
    $scope.model = 'timeProfileModel';

    ManageIQ.angular.scope = $scope;

    miqService.sparkleOn();
    $http.get('/configuration/time_profile_form_fields/' + timeProfileFormId).success(function(data) {
      $scope.timeProfileModel.description = data.description;
      $scope.timeProfileModel.admin_user = data.admin_user;
      $scope.timeProfileModel.restricted_time_profile = data.restricted_time_profile;
      $scope.timeProfileModel.profile_type = data.profile_type;
      $scope.timeProfileModel.profile_tz = data.profile_tz;
      $scope.timeProfileModel.rollup_daily = data.rollup_daily;
      $scope.timeProfileModel.miq_reports_count = data.miq_reports_count;
      $scope.timeProfileModel.all_days = data.all_days;
      $scope.timeProfileModel.days = data.days;
      $scope.timeProfileModel.all_hours = data.all_hours;
      $scope.timeProfileModel.hours = data.hours;
      $scope.getDaysValues();
      $scope.getHoursValues();

      $scope.note = sprintf(__("In use by %s reports, cannot be disabled"), $scope.timeProfileModel.miq_reports_count);

      $scope.afterGet = true;
      $scope.modelCopy                    = angular.copy( $scope.timeProfileModel );

      miqService.sparkleOff();
    });

    if (timeProfileFormId == 'new') {
      $scope.newRecord = true;
    } else {
      $scope.newRecord = false;
    }
  };

  $scope.getDaysValues = function() {
    for(i = 0; i < 7; i++) {
      if ($scope.timeProfileModel.days.indexOf(i) > -1) {
        $scope.timeProfileModel.dayValues.push(true);
      } else {
        $scope.timeProfileModel.dayValues.push(false);
      }
    }
  };

  $scope.dayValuesChanged = function() {
    var tempDays = [];

    for(var i = 0; i < 7; i++) {
      if ($scope.timeProfileModel.dayValues[i] === true) {
        tempDays.push(i);
      }
    }
    $scope.timeProfileModel.days = tempDays;
  };

  $scope.getHoursValues = function() {
    for(i = 0; i < 6; i++) {
      if ($scope.timeProfileModel.hours.indexOf(i) > -1) {
        $scope.timeProfileModel.hourValuesAMFirstHalf.push(true);
      } else {
        $scope.timeProfileModel.hourValuesAMFirstHalf.push(false);
      }
    }
    for(i = 6; i < 12; i++) {
      if ($scope.timeProfileModel.hours.indexOf(i) > -1) {
        $scope.timeProfileModel.hourValuesAMSecondHalf.push(true);
      } else {
        $scope.timeProfileModel.hourValuesAMSecondHalf.push(false);
      }
    }
    for(i = 12; i < 18; i++) {
      if ($scope.timeProfileModel.hours.indexOf(i) > -1) {
        $scope.timeProfileModel.hourValuesPMFirstHalf.push(true);
      } else {
        $scope.timeProfileModel.hourValuesPMFirstHalf.push(false);
      }
    }
    for(i = 18; i < 24; i++) {
      if ($scope.timeProfileModel.hours.indexOf(i) > -1) {
        $scope.timeProfileModel.hourValuesPMSecondHalf.push(true);
      } else {
        $scope.timeProfileModel.hourValuesPMSecondHalf.push(false);
      }
    }
    $scope.calculateTimeProfileHourValues();
  };

  $scope.hourValuesChanged = function() {
    var tempHours = [];

    for(var i = 0; i < 6; i++) {
      if ($scope.timeProfileModel.hourValuesAMFirstHalf[i] === true) {
        tempHours.push(i);
      }
    }
    for(var i = 0, j = 6; i < 6, j < 12; i++, j++) {
      if ($scope.timeProfileModel.hourValuesAMSecondHalf[i] === true) {
        tempHours.push(j);
      }
    }
    for(var i = 0, j = 12; i < 6, j < 18; i++, j++) {
      if ($scope.timeProfileModel.hourValuesPMFirstHalf[i] === true) {
        tempHours.push(j);
      }
    }
    for(var i = 0, j = 18; i < 6, j < 24; i++, j++) {
      if ($scope.timeProfileModel.hourValuesPMSecondHalf[i] === true) {
        tempHours.push(j);
      }
    }
    $scope.timeProfileModel.hours = tempHours;
    $scope.calculateTimeProfileHourValues();
  };

  $scope.calculateTimeProfileHourValues = function() {
    $scope.timeProfileModel.hourValues = [];
    $scope.timeProfileModel.hourValues.push($scope.timeProfileModel.hourValuesAMFirstHalf);
    $scope.timeProfileModel.hourValues.push($scope.timeProfileModel.hourValuesAMSecondHalf);
    $scope.timeProfileModel.hourValues.push($scope.timeProfileModel.hourValuesPMFirstHalf);
    $scope.timeProfileModel.hourValues.push($scope.timeProfileModel.hourValuesPMSecondHalf);
    $scope.timeProfileModel.hourValues = _.flattenDeep($scope.timeProfileModel.hourValues);
  };

  $scope.allDaysClicked = function() {
    if ($scope.timeProfileModel.all_days) {
      $scope.timeProfileModel.dayValues = _.times(7, _.constant(true));
      $scope.timeProfileModel.days = _.times(7, i);
      $scope.timeProfileModel.some_days_checked = true;
    } else {
      $scope.timeProfileModel.dayValues = _.times(7, _.constant(false));
      $scope.timeProfileModel.days = [];
      $scope.timeProfileModel.some_days_checked = false;
    }
  };

  $scope.allHoursClicked = function() {
    if ($scope.timeProfileModel.all_hours) {
      $scope.timeProfileModel.hourValuesAMFirstHalf = _.times(6, _.constant(true));
      $scope.timeProfileModel.hourValuesAMSecondHalf = _.times(6, _.constant(true));
      $scope.timeProfileModel.hourValuesPMFirstHalf = _.times(6, _.constant(true));
      $scope.timeProfileModel.hourValuesPMSecondHalf = _.times(6, _.constant(true));
      $scope.timeProfileModel.hours = _.times(24, i);
      $scope.timeProfileModel.some_hours_checked = true;
    } else {
      $scope.timeProfileModel.hourValuesAMFirstHalf = _.times(6, _.constant(false));
      $scope.timeProfileModel.hourValuesAMSecondHalf = _.times(6, _.constant(false));
      $scope.timeProfileModel.hourValuesPMFirstHalf = _.times(6, _.constant(false));
      $scope.timeProfileModel.hourValuesPMSecondHalf = _.times(6, _.constant(false));
      $scope.timeProfileModel.some_hours_checked = false;
      $scope.timeProfileModel.hours = [];
    }
    $scope.calculateTimeProfileHourValues();
  };

  var timeProfileEditButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = '/configuration/timeprofile_update/' + timeProfileFormId + '?button=' + buttonName;
    var timeProfileModelObj = angular.copy($scope.timeProfileModel);
    delete timeProfileModelObj.profile_tz;
    var moreUrlParams = $.param(miqService.serializeModel(timeProfileModelObj));
    if(moreUrlParams)
      url += '&' + decodeURIComponent(moreUrlParams);
    miqService.miqAjaxButton(url, true);
  };

  $scope.cancelClicked = function() {
    timeProfileEditButtonClicked('cancel');
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.timeProfileModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function() {
    timeProfileEditButtonClicked('save', true);
    $scope.angularForm.$setPristine(true);
  };

  $scope.addClicked = function() {
    $scope.saveClicked();
  };

  init();
}]);
