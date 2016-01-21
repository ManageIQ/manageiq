ManageIQ.angular.app.controller('reconfigureFormController', ['$http', '$scope', 'reconfigureFormId', 'objectIds', 'miqService', function($http, $scope, reconfigureFormId, objectIds, miqService) {
    var init = function() {
      $scope.reconfigureModel = {
        objectIds:               [],
        cb_memory:               false,
        memory:                  '',
        memory_type:             '',
        memory_note:             '',
        cb_cpu:                  false,
        socket_count:            '',
        socket_options:          [1],
        cores_per_soucket_count: '',
        total_cpus:              ''
      };
      $scope.formId = reconfigureFormId;
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
        $scope.reconfigureModel.memory_note            = data.memory_note;
        $scope.reconfigureModel.cb_cpu                 = data.cb_cpu;
        $scope.reconfigureModel.socket_count           = data.socket_count;
        $scope.reconfigureModel.socket_options         = data.socket_options;
        $scope.reconfigureModel.cores_per_socket_count = data.cores_per_socket_count;

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.reconfigureModel );

        miqService.sparkleOff();
      });

      $scope.$watch("reconfigureModel.name", function() {
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
      if($scope.angularForm.url.$valid &&
        $scope.angularForm.log_userid.$valid &&
        $scope.angularForm.log_password.$valid &&
        $scope.angularForm.log_verify.$valid)
        return true;
      else
        return false;
    };

    var reconfigureEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = 'reconfigure_update' + '?button=' + buttonName;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, serializeFields);
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
      reconfigureEditButtonClicked('submit', true);
      $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = function() {
      $scope.submitClicked();
    };

    init();
}]);
