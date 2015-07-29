(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper, navigationHelper) {
    routerHelper.configureStates(getStates());
    navigationHelper.navItems(navItems());
    navigationHelper.sidebarItems(sidebarItems());
  }

  function getStates() {
    return {
      'admin.roles.edit': {
        url: '/edit/:roleId',
        templateUrl: 'app/states/admin/roles/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Edit Role',
        resolve: {
          role: resolveRole
        }
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {};
  }

  /** @ngInject */
  function resolveRole(Role, $stateParams) {
    return Role.get({id: $stateParams.roleId}).$promise;
  }

  /** @ngInject */
  function StateController(logger, role) {
    var vm = this;

    vm.title = 'Edit Role';
    vm.role = role;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Edit Role View');
    }
  }
})();
