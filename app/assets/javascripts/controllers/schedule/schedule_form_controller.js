ManageIQ.angularApplication.controller('scheduleFormController', ['$http', '$scope', 'scheduleFormId', 'oneMonthAgo', 'miqService', 'timerOptionService', function($http, $scope, scheduleFormId, oneMonthAgo, miqService, timerOptionService) {
  var init = function() {

    $scope.scheduleModel = {
      action_typ: '',
      depot_name: '',
      filter_typ: '',
      log_userid: '',
      log_password: '',
      log_verify: '',
      log_protocol: '',
      description: '',
      enabled: '',
      name: '',
      timer_typ: '',
      timer_value: '',
      start_date: null,
      start_hour: '',
      start_min: '',
      time_zone: '',
      uri: '',
      uri_prefix: '',
      filter_value: ''
    };
    $scope.date_from = null;
    $scope.formId = scheduleFormId;
    $scope.afterGet = false;
    $scope.validateClicked = miqService.validateWithAjax;
    $scope.modelCopy = angular.copy( $scope.scheduleModel );

    ManageIQ.angularApplication.$scope = $scope;

    if (scheduleFormId == 'new') {
      $scope.newRecord                = true;
      $scope.scheduleModel.action_typ = 'vm';
      $scope.scheduleModel.filter_typ = 'all';
      $scope.scheduleModel.enabled    = true;
      $scope.filterValuesEmpty        = true;
      $scope.scheduleModel.start_date = moment(moment.utc().add(1, 'days').toDate()).format('MM/DD/YYYY');
      $scope.scheduleModel.timer_typ  = 'Once';
      $scope.scheduleModel.time_zone  = 'UTC';
      $scope.scheduleModel.start_hour = '0';
      $scope.scheduleModel.start_min  = '0';
      $scope.afterGet                 = true;
      $scope.modelCopy                = angular.copy( $scope.scheduleModel );
      $scope.setTimerType();
      $scope.date_from = new Date();
    } else {
      $scope.newRecord = false;

      miqService.sparkleOn();

      $http.get('/ops/schedule_form_fields/' + scheduleFormId).success(function(data) {
        $scope.scheduleModel.action_typ   = data.action_type;
        $scope.scheduleModel.depot_name   = data.depot_name;
        $scope.scheduleModel.filter_typ   = data.filter_type;
        $scope.scheduleModel.log_userid   = data.log_userid;
        $scope.scheduleModel.log_password = data.log_password;
        $scope.scheduleModel.log_verify   = data.log_verify;
        $scope.scheduleModel.log_protocol = data.protocol;
        $scope.scheduleModel.description  = data.schedule_description;
        $scope.scheduleModel.enabled      = data.schedule_enabled == "1" ? true : false;
        $scope.scheduleModel.name         = data.schedule_name;
        $scope.scheduleModel.timer_typ    = data.schedule_timer_type;
        $scope.scheduleModel.timer_value  = data.schedule_timer_value;
        $scope.scheduleModel.start_date   = data.schedule_start_date;
        $scope.scheduleModel.start_hour   = data.schedule_start_hour.toString();
        $scope.scheduleModel.start_min    = data.schedule_start_min.toString();
        $scope.scheduleModel.time_zone    = data.schedule_time_zone;
        $scope.scheduleModel.uri          = data.uri;
        $scope.scheduleModel.uri_prefix   = data.uri_prefix;

        $scope.setTimerType();


        $scope.timer_items        = timerOptionService.getOptions($scope.scheduleModel.timer_typ);

        if (data.filter_type === 'all' || (data.protocol !== undefined && data.protocol !== null)) {
          $scope.filterValuesEmpty = true;
        } else {
          buildFilterList(data);

          $scope.filterValuesEmpty = false;
          $scope.scheduleModel.filter_value     = data.filter_value;
        }

        if(data.filter_type == null &&
          (data.protocol !== undefined && data.protocol !== null && data.protocol != 'Samba'))
          $scope.scheduleModel.filter_typ = 'all';

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.scheduleModel );

        miqService.sparkleOff();
      });
    }

    miqService.buildCalendar(oneMonthAgo.year, parseInt(oneMonthAgo.month) + 1, oneMonthAgo.date);

    $scope.$watch("scheduleModel.name", function() {
      $scope.form = $scope.angularForm;
      $scope.model = "scheduleModel";
    });
  };

  var buildFilterList = function(data) {
    $scope.filterList = [];
    angular.forEach(data.filtered_item_list, function(filteredItem) {
      var tempObj = {};

      if (Object.prototype.toString.call(filteredItem) === '[object Array]') {
        tempObj.text = filteredItem[1];
        tempObj.value = filteredItem[0];
      } else {
        tempObj.text = filteredItem;
        tempObj.value = filteredItem;
      }

      $scope.filterList.push(tempObj);
    });
  };

  var testType = function(type) {
    return type.test($scope.scheduleModel.action_typ);
  };

  var isVmType = function() {
    return testType(/^vm/);
  };

  var isHostType = function() {
    return testType(/^host/);
  };

  var scheduleEditButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = '/ops/schedule_edit/' + scheduleFormId + '?button=' + buttonName;
    if (serializeFields === undefined) {
      miqService.miqAjaxButton(url);
    } else {
      miqService.miqAjaxButton(url, serializeFields);
    }
  };

  $scope.buildLegend = function() {
    var type;

    if (isVmType()) {
      type = 'VM';
    } else if (isHostType()) {
      type = 'Host';
    } else if ($scope.scheduleModel.action_typ === 'miq_template') {
      type = 'Template';
    } else if ($scope.scheduleModel.action_typ === 'emscluster') {
      type = 'Cluster';
    } else if ($scope.scheduleModel.action_typ === 'storage') {
      type = 'Datastore';
    } else if ($scope.scheduleModel.action_typ === 'db_backup') {
      type = 'Database Backup';
    }

    return type + ' Selection';
  };

  $scope.determineActionType = function() {
    if (isVmType()) {
      return 'vm';
    } else if (isHostType()) {
      return 'host';
    } else {
      return $scope.scheduleModel.action_typ;
    }
  };

  $scope.dbBackup = function() {
    return $scope.scheduleModel.action_typ === 'db_backup';
  };

  $scope.sambaBackup = function() {
    return $scope.dbBackup() && $scope.scheduleModel.log_protocol === 'Samba';
  };

  $scope.actionTypeChanged = function() {
    if ($scope.dbBackup()) {
      $scope.scheduleModel.log_protocol = 'Network File System';
      $scope.scheduleModel.uri_prefix = 'nfs';
      $scope.scheduleModel.filter_typ = null;
    } else {
      $scope.scheduleModel.filter_typ = 'all';
    }
    $scope.scheduleModel.filter_value = '';

    $scope.filterValuesEmpty = true;
  };

  $scope.filterTypeChanged = function() {
    if ($scope.scheduleModel.filter_typ != 'all') {
      miqService.sparkleOn();
      $http.post('/ops/schedule_form_filter_type_field_changed/' + scheduleFormId, {filter_type: $scope.scheduleModel.filter_typ}).success(function(data) {
        buildFilterList(data);
        $scope.filterValuesEmpty = false;
        miqService.sparkleOff();
      });
    } else {
      $scope.scheduleModel.filter_value = '';
      $scope.filterValuesEmpty = true;
    }
  };

  $scope.logProtocolChanged = function() {
    if ($scope.scheduleModel.log_protocol === "Samba") {
      $scope.scheduleModel.uri_prefix = "smb";
    }

    if ($scope.scheduleModel.log_protocol === "Network File System") {
      $scope.scheduleModel.uri_prefix = "nfs";
    }
  };

  $scope.filterValueChanged = function() {
  };

  $scope.scheduleTimerTypeChanged = function() {
    $scope.setTimerType();

    $scope.timer_items = timerOptionService.getOptions($scope.scheduleModel.timer_typ);

    if ($scope.timerNotOnce()) {
      $scope.scheduleModel.timer_value = 1;
    } else {
      $scope.scheduleModel.timer_value = 0;
    }
  };

  $scope.timerNotOnce = function() {
    return $scope.scheduleModel.timer_typ !== 'Once';
  };

  $scope.cancelClicked = function() {
    scheduleEditButtonClicked('cancel');
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.scheduleModel = angular.copy( $scope.modelCopy );
    if($scope.dbBackup())
        $scope.filterValuesEmpty = true;

      if($scope.scheduleModel.filter_typ &&
          ($scope.form.action_typ.$untouched && $scope.form.filter_typ.$untouched)) {

        //AJAX-less Reset
        $scope.toggleValueForWatch('filterValuesEmpty', false);
      }

    if($scope.scheduleModel.filter_typ &&
      ($scope.form.action_typ.$touched || $scope.form.filter_typ.$touched)) {
      $scope.filterTypeChanged();
    }
    if($scope.scheduleModel.timer_typ && $scope.form.timer_typ.$touched) {
      $scope.setTimerType();
      $scope.timer_items = timerOptionService.getOptions($scope.scheduleModel.timer_typ);
    }
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  $scope.saveClicked = function() {
    scheduleEditButtonClicked('save', true);
    $scope.angularForm.$setPristine(true);
  };

  $scope.addClicked = function() {
    $scope.saveClicked();
  };

  $scope.filterValueRequired = function(value) {
    return !$scope.filterValuesEmpty &&
      ($scope.isModelValueNil(value));
  };

  $scope.dbRequired = function(value) {
    return $scope.dbBackup() &&
      ($scope.isModelValueNil(value));
  };

  $scope.sambaRequired = function(value) {
    return $scope.sambaBackup() &&
      ($scope.isModelValueNil(value));
  };

  $scope.isModelValueNil = function(value) {
    return value == null || value == '';
  };

  $scope.isBasicInfoValid = function() {
    if($scope.angularForm.depot_name.$valid &&
      $scope.angularForm.uri.$valid &&
      $scope.angularForm.log_userid.$valid &&
      $scope.angularForm.log_password.$valid &&
      $scope.angularForm.log_verify.$valid)
      return true;
    else
      return false;
  };

  $scope.setTimerType = function() {
    if ($scope.scheduleModel.timer_typ == "Once")
      $scope.timerTypeOnce = true;
    else {
      $scope.timerTypeOnce = false;
    }
  };

  $scope.toggleValueForWatch =   function(watchValue, initialValue) {
    if($scope[watchValue] == initialValue)
      $scope[watchValue] = "NO-OP";
    else if($scope[watchValue] == "NO-OP")
      $scope[watchValue] = initialValue;
  };

  $scope.canValidate = function () {
    if ($scope.isBasicInfoValid() && $scope.validateFieldsDirty())
      return true;
    else
      return false;
  }

  $scope.canValidateBasicInfo = function () {
    if ($scope.isBasicInfoValid())
      return true;
    else
      return false;
  }

  $scope.validateFieldsDirty = function () {
    if ($scope.angularForm.depot_name.$dirty ||
        $scope.angularForm.uri.$dirty ||
        $scope.angularForm.log_userid.$dirty ||
        $scope.angularForm.log_password.$dirty ||
        $scope.angularForm.log_verify.$dirty)
      return true;
    else
      return false;
  }

  init();
}]);

