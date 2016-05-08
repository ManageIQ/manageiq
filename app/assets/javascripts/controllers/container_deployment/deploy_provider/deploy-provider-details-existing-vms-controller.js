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
          title: 'Name',
          sortType: 'alpha'
        },
        {
          id: 'role',
          title: 'Role',
          sortType: 'alpha'
        },
        {
          id: 'cpus',
          title: '# CPUS',
          sortType: 'numeric'
        },
        {
          id: 'memory',
          title: 'Memory',
          sortType: 'numeric'
        },
        {
          id: 'diskSize',
          title: 'Disk Size',
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
