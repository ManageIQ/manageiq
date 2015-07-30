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
      'admin.roles.create': {
        url: '/create',
        templateUrl: 'app/states/admin/roles/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Roles Create'
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
  function StateController(logger, Role) {
    var vm = this;

    vm.title = 'Admin Role Create';

    vm.activate = activate;

    activate();

    function activate() {
      initRole();
      logger.info('Activated Admin Products Create View');
    }

    // Private

    function initRole() {
      vm.role = Role.new();
    }
  }
})();
