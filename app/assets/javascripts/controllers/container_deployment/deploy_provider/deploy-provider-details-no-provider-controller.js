miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderDetailsNoProviderController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';

    $scope.showAddDialog = false;
    $scope.newItem = {};

    $scope.updateNodeSettings();

    $scope.cancelAddDialog = function () {
      $scope.showAddDialog = false;
    };

    $scope.saveAddDialog = function () {
      if ($scope.newHost.vmName && $scope.newHost.vmName.length > 0) {
        $scope.nodeData.allNodes.push($scope.newHost);
        $scope.showAddDialog = false;
        $scope.updateNodeSettings();
        $scope.nodeData.userDefinedVMs = $scope.nodeData.allNodes;
      }
    };

    var userUpdatedPublicName = false;
    $scope.addVM = function () {
      $scope.newHost = {
        vmName: "",
        publicName: "",
        master: false,
        node: false,
        storage: false,
        loadBalancer: false,
        dns: false,
        etcd: false,
        infrastructure: false
      };
      userUpdatedPublicName = false;
      $scope.showAddDialog = true;

      $timeout(function() {
        $document[0].getElementById('add-private-name').focus();
      }, 200);
    };

    $scope.newVmSelectAll = function () {
      $scope.newHost.master = true;
      $scope.newHost.node = true;
      $scope.newHost.storage = true;
      $scope.newHost.loadBalancer = true;
      $scope.newHost.dns = true;
      $scope.newHost.etcd = true;
      $scope.newHost.infrastructure = true;
    };

    var removeItems = function () {
      $scope.nodeData.allNodes = $scope.nodeData.allNodes.filter(function(item) {
        return !item.selected;
      });
      $scope.nodeData.userDefinedVMs = $scope.nodeData.allNodes;
      $scope.updateNodeSettings();
    };

    var actionsConfig = {
      actionsInclude: true,
      moreActions: [
        {
          name: __('Remove Roles'),
          actionFn: $scope.removeRoles
        },
        {
          name: __('Remove VM(s)'),
          title: 'Clear the selected items.',
          actionFn: removeItems
        }
      ]
    };

    var sortChange = function () {
      $scope.sortConfig.currentField = sortConfig.currentField;
      $scope.sortConfig.isAscending = sortConfig.isAscending;
      $scope.sortChange();
    };


    var sortConfig = {
      fields: [
        {
          id: 'name',
          title: __('Name'),
          sortType: 'alpha'
        },
        {
          id: 'role',
          title: __('Role'),
          sortType: 'alpha'
        }
      ],
      onSortChange: sortChange
    };
    sortConfig.currentField = sortConfig.fields[1];

    $scope.toolbarConfig = {
      sortConfig: sortConfig,
      actionsConfig: actionsConfig
    };


    $scope.updateNewVMName = function () {
      if (!userUpdatedPublicName) {
        $scope.newHost.publicName = $scope.newHost.vmName;
      }
    };

    $scope.updateNewVMPublicName = function () {
      if ($scope.newHost.publicName != $scope.newHost.vmName) {
        userUpdatedPublicName = true;
      } else {
        userUpdatedPublicName = false;
      }
    };
  }
]);
