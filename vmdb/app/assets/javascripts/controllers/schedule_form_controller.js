cfmeAngularApplication.controller('scheduleFormController', ['$http', '$scope', 'storageTable', function($http, $scope, storageTable) {
  $scope.action_type = 'vm';
  $scope.filter_type = 'all';
  $scope.filterValuesEmpty = true;

  var testType = function(type) {
    return type.test($scope.action_type);
  }

  var isVmType = function() {
    return testType(/^vm/);
  }

  var isHostType = function() {
    return testType(/^host/);
  }

  $scope.buildLegend = function() {
    var type;

    if (isVmType()) {
      type = 'VM';
    } else if (isHostType()) {
      type = 'Host';
    } else if ($scope.action_type == 'miq_template') {
      type = 'Template';
    } else if ($scope.action_type == 'emscluster') {
      type = 'Cluster';
    } else if ($scope.action_type == 'storage') {
      type = storageTable;
    } else if ($scope.action_type == 'db_backup') {
      type = 'Database Backup';
    }

    return type + ' Selection';
  }

  $scope.determineActionType = function() {
    if (isVmType()) {
      return 'vm';
    } else if (isHostType()) {
      return 'host';
    } else {
      return $scope.action_type;
    }
  }

  $scope.sambaBackup = function() {
    return $scope.action_type === 'db_backup' && $scope.log_protocol === 'Samba';
  }

  $scope.actionTypeChanged = function() {
    if ($scope.action_type === 'db_backup') {
      $scope.log_protocol = 'Network File System';
    } else {
      $scope.filter_type = 'all';
      $scope.filterValuesEmpty = true;
    }
  }

  $scope.filterTypeChanged = function() {
    if ($scope.filter_type != 'all') {
      $http.put('/ops/schedule_form_field_change', {filter_type: $scope.filter_type}).success(function(data) {
        if (Object.prototype.toString.call(data.filtered_item_list[0]) === '[object Array]') {
          $scope.filterList = data.filtered_item_list;
        } else {
          $scope.filterList = [];

          for (index in data.filtered_item_list) {
            $scope.filterList[index] = [];
            $scope.filterList[index][0] = data.filtered_item_list[index];
            $scope.filterList[index][1] = data.filtered_item_list[index];
          }
        }
        $scope.filterValuesEmpty = false;
      });
    } else {
      $scope.filterValuesEmpty = true;
    }
  }
}]);
