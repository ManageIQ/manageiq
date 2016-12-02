ManageIQ.angular.app.controller('reconfigureFormController', ['$http', '$scope', 'reconfigureFormId', 'objectIds', 'miqService', function($http, $scope, reconfigureFormId, objectIds, miqService) {
    var init = function() {
      $scope.reconfigureModel = {
        memory:                  '0',
        memory_type:             '',
        socket_count:            '1',
        cores_per_socket_count:  '1',
        total_cpus:              '1',
        vmdisks:                 [],
        hdType:                  'thin',
        hdMode:                  'persistent',
        hdSize:                  '',
        hdUnit:                  'MB',
        cb_dependent:            true,
        addEnabled:              false,
        cb_bootable:             false,
        vmAddDisks:              [],
        vmRemoveDisks:           []
      };
      $scope.cb_disks = false;
      $scope.hdpattern = "^[1-9][0-9]*$";
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
      $http.get('reconfigure_form_fields/' + reconfigureFormId + ',' + $scope.objectIds).success(function(data) {
        $scope.reconfigureModel.memory                 = data.memory;
        $scope.reconfigureModel.memory_type            = data.memory_type;
        $scope.reconfigureModel.socket_count           = data.socket_count;
        $scope.reconfigureModel.cores_per_socket_count = data.cores_per_socket_count;
        $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
        $scope.cb_memory = data.cb_memory;
        $scope.cb_cpu = data.cb_cpu;
        $scope.reconfigureModel.vmdisks = angular.copy(data.disks);

        $scope.updateDisksAddRemove();

        for (var disk in $scope.reconfigureModel.vmdisks)
          if($scope.reconfigureModel.vmdisks[disk]['add_remove'] == '' )
            $scope.reconfigureModel.vmdisks[disk]['delete_backing'] = false;

        if(data.socket_count && data.cores_per_socket_count)
          $scope.reconfigureModel.total_cpus = (parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10)).toString();
        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.reconfigureModel );
        $scope.cb_memoryCopy = $scope.cb_memory;
        $scope.cb_cpuCopy = $scope.cb_cpu;

        miqService.sparkleOff();
      });
    };

    $scope.canValidateBasicInfo = function () {
      if ($scope.isBasicInfoValid())
        return true;
      else
        return false;
    };

    $scope.isBasicInfoValid = function() {
      if(( $scope.angularForm.memory && !$scope.angularForm.memory.$valid) ||
        ($scope.angularForm.socket_count && !$scope.angularForm.socket_count.$valid) ||
        ($scope.angularForm.mem_type && !$scope.angularForm.mem_type.$valid) ||
        ($scope.angularForm.cores_per_socket_count && !$scope.angularForm.cores_per_socket_count.$valid) ||
        ($scope.angularForm.total_cpus && !$scope.angularForm.total_cpus.$valid)
        ($scope.angularForm.hdSize && !$scope.angularForm.hdSize.$valid))
        return false;
      else
        return true;
    };

    $scope.cbChange = function() {
      var memUnchanged = false;
      var cpuUnchanged = false;
      miqService.miqFlashClear();

      if (!$scope.newRecord)
        return;
      $scope.angularForm.$setValidity("unchanged", true);

      if ($scope.cb_memory) {
        var memorynow = $scope.reconfigureModel.memory;
        var memoryprev = $scope.modelCopy.memory;
        if ($scope.reconfigureModel.memory_type == 'GB')
          memorynow *= 1024;
        if($scope.modelCopy.memory_type == 'GB')
          memoryprev *= 1024;
        if (memorynow == memoryprev)
          memUnchanged = true;
      }

      if ($scope.cb_cpu && (($scope.reconfigureModel.socket_count == $scope.modelCopy.socket_count)) &&
        ($scope.reconfigureModel.cores_per_socket_count == $scope.modelCopy.cores_per_socket_count))
        cpuUnchanged = true;

      if ($scope.cb_memory && $scope.cb_cpu && memUnchanged && cpuUnchanged) {
        miqService.miqFlash("warn", "Change Memory and Processor value to submit reconfigure request");
        $scope.angularForm.$setValidity("unchanged", false);
      } else {
        if ($scope.cb_memory && memUnchanged) {
          miqService.miqFlash("warn", "Change Memory value to submit reconfigure request");
          $scope.angularForm.$setValidity("unchanged", false);
        }
        if ($scope.cb_cpu && cpuUnchanged) {
          miqService.miqFlash("warn", "Change Processor Sockets or Cores Per Socket value to submit reconfigure request");
          $scope.angularForm.$setValidity("unchanged", false);
        }
      }
    };

    $scope.processorValueChanged = function() {
      if ($scope.reconfigureModel.socket_count != '' && $scope.reconfigureModel.cores_per_socket_count != '') {
        var vtotal_cpus = parseInt($scope.reconfigureModel.socket_count, 10) * parseInt($scope.reconfigureModel.cores_per_socket_count, 10);
        $scope.reconfigureModel.total_cpus = vtotal_cpus.toString();
      }
      $scope.cbChange();
    };

    $scope.memtypeChanged = function() {
      if ($scope.reconfigureModel.memory_type == "GB" && $scope.mem_type_prev == "MB")
        $scope.reconfigureModel.memory = ~~(parseInt($scope.reconfigureModel.memory, 10) / 1024);
      else if ($scope.reconfigureModel.memory_type == "MB" && $scope.mem_type_prev == "GB")
        $scope.reconfigureModel.memory =  parseInt($scope.reconfigureModel.memory, 10) * 1024;
      $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
      $scope.angularForm['memory'].$validate();
      $scope.cbChange();
    };


    $scope.updateDisksAddRemove = function() {
      $scope.reconfigureModel.vmAddDisks.length = 0;
      $scope.reconfigureModel.vmRemoveDisks.length = 0;
      for (var disk in $scope.reconfigureModel.vmdisks) {
        if ($scope.reconfigureModel.vmdisks[disk]['add_remove'] === 'remove') {
          $scope.reconfigureModel.vmRemoveDisks.push({disk_name: $scope.reconfigureModel.vmdisks[disk].hdFilename,
                                     delete_backing: $scope.reconfigureModel.vmdisks[disk].delete_backing});
        } else if ($scope.reconfigureModel.vmdisks[disk]['add_remove'] === 'add') {
          var dsize = parseInt($scope.reconfigureModel.vmdisks[disk].hdSize, 10);
          if ($scope.reconfigureModel.vmdisks[disk].hdUnit == 'GB')
            dsize *= 1024;
          var dmode = ($scope.reconfigureModel.vmdisks[disk].hdMode == 'persistent');
          var dtype = ($scope.reconfigureModel.vmdisks[disk].hdType == 'thin');
          $scope.reconfigureModel.vmAddDisks.push({disk_size_in_mb: dsize,
                                                   persistent: dmode,
                                                   thin_provisioned: dtype,
                                                   dependent: $scope.reconfigureModel.vmdisks[disk].cb_dependent,
                                                   bootable: $scope.reconfigureModel.vmdisks[disk].cb_bootable});
        }
      }
    };

    $scope.resetAddValues = function() {
      $scope.reconfigureModel.hdType = 'thin';
      $scope.reconfigureModel.hdMode = 'persistent';
      $scope.reconfigureModel.hdSize = '';
      $scope.reconfigureModel.hdUnit = 'MB';
      $scope.reconfigureModel.cb_dependent = true;
      $scope.reconfigureModel.addEnabled = false;
      $scope.reconfigureModel.cb_bootable = false;
    };

    $scope.addDisk = function() {
      $scope.reconfigureModel.vmdisks.push({hdFilename:'',
                                            hdType: $scope.reconfigureModel.hdType,
                                            hdMode: $scope.reconfigureModel.hdMode,
                                            hdSize: $scope.reconfigureModel.hdSize,
                                            hdUnit: $scope.reconfigureModel.hdUnit,
                                            cb_dependent: $scope.reconfigureModel.cb_dependent,
                                            cb_bootable: $scope.reconfigureModel.cb_bootable,
                                            add_remove: 'add'});
      $scope.resetAddValues();

      $scope.updateDisksAddRemove();

      if( $scope.reconfigureModel.vmAddDisks.length > 0  || $scope.reconfigureModel.vmRemoveDisks.length > 0)
        $scope.cb_disks = true;
      else
        $scope.cb_disks = false;
    };

    $scope.enableDiskAdd = function() {
      $scope.reconfigureModel.addEnabled = true;
    };

    $scope.hideAddDisk = function() {
      $scope.reconfigureModel.addEnabled = false;
      $scope.resetAddValues();
    };

    $scope.deleteDisk = function(name) {
      for (var disk in $scope.reconfigureModel.vmdisks) {
        if ($scope.reconfigureModel.vmdisks[disk].hdFilename === name)
          $scope.reconfigureModel.vmdisks[disk]['add_remove'] = 'remove';
      }
      $scope.updateDisksAddRemove();

      if( $scope.reconfigureModel.vmAddDisks.length > 0  || $scope.reconfigureModel.vmRemoveDisks.length > 0)
        $scope.cb_disks = true;
      else
        $scope.cb_disks = false;
    };

    $scope.cancelAddRemoveDisk = function(vmDisk) {
      for (var disk in $scope.reconfigureModel.vmdisks) {
        if ($scope.reconfigureModel.vmdisks[disk].hdFilename === vmDisk['hdFilename']) {
          if ($scope.reconfigureModel.vmdisks[disk]['add_remove'] === 'remove') {
            $scope.reconfigureModel.vmdisks[disk]['add_remove'] = '';
            $scope.reconfigureModel.vmdisks[disk]['cb_deletebacking'] = false;
            $scope.reconfigureModel.vmdisks[disk]['cb_bootable'] = false;
          } else if ($scope.reconfigureModel.vmdisks[disk]['add_remove'] === 'add') {
            var index = $scope.reconfigureModel.vmdisks.indexOf(vmDisk);
            $scope.reconfigureModel.vmdisks.splice(index, 1);
            break;
          }
        }
      }
      $scope.updateDisksAddRemove();

      if (!angular.equals($scope.reconfigureModel.vmAddDisks, $scope.modelCopy.vmAddDisks) || !angular.equals($scope.reconfigureModel.vmRemoveDisks, $scope.modelCopy.vmRemoveDisks))
        $scope.cb_disks = true;
      else
        $scope.cb_disks = false;
    };

    var reconfigureEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = 'reconfigure_update/' + reconfigureFormId + '?button=' + buttonName;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, {objectIds:              $scope.objectIds,
                                       cb_memory:              $scope.cb_memory,
                                       cb_cpu:                 $scope.cb_cpu,
                                       memory:                 $scope.reconfigureModel.memory,
                                       memory_type:            $scope.reconfigureModel.memory_type,
                                       socket_count:           $scope.reconfigureModel.socket_count,
                                       cores_per_socket_count: $scope.reconfigureModel.cores_per_socket_count,
                                       vmAddDisks:             $scope.reconfigureModel.vmAddDisks,
                                       vmRemoveDisks:          $scope.reconfigureModel.vmRemoveDisks
                                      });
      }
    };

    $scope.cancelClicked = function() {
      miqService.sparkleOn();
      miqService.miqAjaxButton('reconfigure_update?button=cancel');
    };

    $scope.resetClicked = function() {
      $scope.$broadcast ('resetClicked');
      $scope.reconfigureModel = angular.copy($scope.modelCopy);
      $scope.cb_memory = $scope.cb_memoryCopy;
      $scope.cb_cpu = $scope.cb_cpuCopy;
      $scope.mem_type_prev = $scope.reconfigureModel.memory_type;
      $scope.angularForm.$setPristine(true);
      $scope.updateDisksAddRemove();
      if (!angular.equals($scope.reconfigureModel.vmAddDisks, $scope.modelCopy.vmAddDisks) || !angular.equals($scope.reconfigureModel.vmRemoveDisks, $scope.modelCopy.vmRemoveDisks))
        $scope.cb_disks = true;
      else
        $scope.cb_disks = false;
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
