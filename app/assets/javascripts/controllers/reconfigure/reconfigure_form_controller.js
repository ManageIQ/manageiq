ManageIQ.angular.app.controller('reconfigureFormController', ['$http', '$scope', 'reconfigureFormId', 'objectIds', 'miqService', function($http, $scope, reconfigureFormId, objectIds, miqService) {
    var init = function() {
      $scope.reconfigureModel = {
        memory:                  '0',
        memory_type:             '',
        socket_count:            '1',
        cores_per_socket_count:  '1',
        total_cpus:              '1'
      };
      $scope.reconfigureFormId = reconfigureFormId;
      $scope.afterGet = false;
      $scope.objectIds = objectIds;
      $scope.cb_memory = $scope.cb_memoryCopy = false;
      $scope.cb_cpu = $scope.cb_cpuCopy = false;

      $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
      $scope.validateClicked = miqService.validateWithAjax;
      $scope.modelCopy = angular.copy( $scope.reconfigureModel );
      $scope.model = 'reconfigureModel';

      ManageIQ.angular.scope = $scope;

      if (reconfigureFormId == 'new')
        $scope.newRecord = true;
      else
        $scope.newRecord = false;

      miqService.sparkleOn();
      $http.get('reconfigure_form_fields/'+ reconfigureFormId + ',' + $scope.objectIds).success(function(data) {
        $scope.reconfigureModel.memory                 = data.memory;
        $scope.reconfigureModel.memory_type            = data.memory_type;
        $scope.reconfigureModel.socket_count           = data.socket_count;
        $scope.reconfigureModel.cores_per_socket_count = data.cores_per_socket_count;
        $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
        $scope.cb_memory = data.cb_memory;
        $scope.cb_cpu = data.cb_cpu;

        if(data.socket_count && data.cores_per_socket_count)
          $scope.reconfigureModel.total_cpus = (parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10)).toString();
        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.reconfigureModel );
        $scope.cb_memoryCopy = $scope.cb_memory;
        $scope.cb_cpuCopy = $scope.cb_cpu;

        miqService.sparkleOff();
      });

      $scope.$watch("reconfigureModel.memory", function() {
        $scope.form = $scope.angularForm;
      });
    };

    $scope.canValidateBasicInfo = function () {
      if ($scope.isBasicInfoValid())
        return true;
      else
        return false;
    };

    $scope.isBasicInfoValid = function() {
      if($scope.angularForm.memory.$valid &&
        $scope.angularForm.socket_count.$valid &&
        $scope.angularForm.memory_type.$valid &&
        $scope.angularForm.cores_per_socket_count.$valid &&
        $scope.angularForm.total_cpus.$valid)
        return true;
      else
        return false;
    };

    $scope.cbChange = function() {
      if( $scope.cb_memory && ($scope.reconfigureModel.memory != $scope.modelCopy.memory))
        return;
      if( $scope.cb_cpu && (($scope.reconfigureModel.socket_count != $scope.modelCopy.socket_count)) ||
        ($scope.reconfigureModel.cores_per_socket_count != $scope.modelCopy.cores_per_socket_count))
        return;
      $scope.angularForm.$setPristine(true);
    };

    $scope.processorValueChanged = function() {
      if($scope.reconfigureModel.socket_count != '' && $scope.reconfigureModel.cores_per_socket_count != '') {
        var vtotal_cpus = parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10);
        $scope.reconfigureModel.total_cpus = vtotal_cpus.toString();
      }
    };

    $scope.memtypeChanged = function() {
      if($scope.reconfigureModel.memory_type == "GB" && $scope.mem_type_prev == "MB")
        $scope.reconfigureModel.memory = ~~(parseInt($scope.reconfigureModel.memory, 10) / 1024);
      else if($scope.reconfigureModel.memory_type == "MB" && $scope.mem_type_prev == "GB")
        $scope.reconfigureModel.memory =  ~~(parseInt($scope.reconfigureModel.memory, 10) * 1024);
      $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
      $scope.angularForm.memory.$validate();
    };

    var reconfigureEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = 'reconfigure_update' + '?button=' + buttonName;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, {objectIds:              $scope.objectIds,
                                       cb_memory:              $scope.cb_memory,
                                       cb_cpu:                 $scope.cb_cpu,
                                       memory:                 $scope.reconfigureModel.memory,
                                       memory_type:            $scope.reconfigureModel.memory_type,
                                       socket_count:           $scope.reconfigureModel.socket_count,
                                       cores_per_socket_count: $scope.reconfigureModel.cores_per_socket_count});
      }
    };

    $scope.cancelClicked = function() {
      miqService.sparkleOn();
      miqService.miqAjaxButton('reconfigure_update?button=cancel');
    };

    $scope.resetClicked = function() {
      $scope.$broadcast ('resetClicked');
      $scope.reconfigureModel = angular.copy( $scope.modelCopy );
      $scope.cb_memory = $scope.cb_memoryCopy;
      $scope.cb_cpu = $scope.cb_cpuCopy;
      $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.submitClicked = function() {
      // change memory value based ontype
      reconfigureEditButtonClicked('submit', true);
      $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = function() {
      $scope.submitClicked();
    };

    init();
}]);
