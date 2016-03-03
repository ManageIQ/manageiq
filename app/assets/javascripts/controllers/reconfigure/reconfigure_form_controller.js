ManageIQ.angular.app.controller('reconfigureFormController', ['$http', '$scope', 'reconfigureFormId', 'objectIds', 'miqService', function($http, $scope, reconfigureFormId, objectIds, miqService) {
    var init = function() {
      $scope.reconfigureModel = {
        objectIds:               [],
        cb_memory:               false,
        memory:                  0,
        memory_type:             '',
        cb_cpu:                  false,
        socket_count:            1,
        socket_options:          [],
        cores_per_socket_count:  1,
        total_cpus:              1
      };
      $scope.reconfigureFormId = reconfigureFormId;
      $scope.afterGet = false;
      $scope.objectIds = objectIds;
      $scope.validateClicked = miqService.validateWithAjax;
      $scope.modelCopy = angular.copy( $scope.reconfigureModel );
      $scope.model = 'reconfigureModel';

      ManageIQ.angular.scope = $scope;

      miqService.sparkleOn();
      $http.get('reconfigure_form_fields/'+ objectIds[0]).success(function(data) {
        $scope.reconfigureModel.objectIds              = data.objectIds;
        $scope.reconfigureModel.cb_memory              = data.cb_memory;
        $scope.reconfigureModel.memory                 = data.memory;
        $scope.reconfigureModel.memory_type            = data.memory_type;
        $scope.reconfigureModel.cb_cpu                 = data.cb_cpu;
        $scope.reconfigureModel.socket_count           = data.socket_count;
        $scope.reconfigureModel.socket_options         = data.socket_options;
        $scope.reconfigureModel.cores_per_socket_count = data.cores_per_socket_count;
        if ( data.socket_count && data.cores_per_socket_count )
          $scope.reconfigureModel.total_cpus = parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10);

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.reconfigureModel );

        miqService.sparkleOff();
      });

      $scope.$watch("reconfigureModel.objectIds", function() {
        $scope.form = $scope.angularForm;
      });
    };

    $scope.canValidateBasicInfo = function () {
      if ($scope.isBasicInfoValid())
        return true;
      else
        return false;
    }

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

    $scope.processorValueChanged = function() {
      $scope.reconfigureModel.total_cpus = parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10);
    };

    var reconfigureEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = 'reconfigure_update' + '?button=' + buttonName;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, {cb_memory:
                                       $scope.reconfigureModel.cb_memory,
                                       memory:                 $scope.reconfigureModel.memory,
                                       memory_type:            $scope.reconfigureModel.memory_type,
                                       cb_cpu:                 $scope.reconfigureModel.memory_type,
                                       socket_count:           $scope.reconfigureModel.cb_cpu,
                                       cores_per_socket_count: $scope.reconfigureModel.cores_per_socket_count});
      }
    };

    $scope.cancelClicked = function() {
      reconfigureEditButtonClicked('cancel');
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.$broadcast ('resetClicked');
      $scope.reconfigureModel = angular.copy( $scope.modelCopy );
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
