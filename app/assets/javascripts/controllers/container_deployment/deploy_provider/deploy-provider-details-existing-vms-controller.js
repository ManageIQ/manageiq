miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderDetailsExistingVMsController',
  ['$rootScope', '$scope',
  function($rootScope, $scope) {
    'use strict';

    var actionsConfig = {
      actionsInclude: true
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
        },
        {
          id: 'cpus',
          title: __('# CPUS'),
          sortType: 'numeric'
        },
        {
          id: 'memory',
          title: __('Memory'),
          sortType: 'numeric'
        },
        {
          id: 'diskSize',
          title: __('Disk Size'),
          sortType: 'numeric'
        }
      ],
      onSortChange: sortChange
    };
    sortConfig.currentField = sortConfig.fields[1];

    $scope.toolbarConfig = {
      filterConfig: $scope.filterConfig,
      sortConfig: sortConfig,
      actionsConfig: actionsConfig
    };
  }
]);
