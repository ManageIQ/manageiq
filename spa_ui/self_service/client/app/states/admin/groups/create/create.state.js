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
      'admin.groups.create': {
        url: '/create',
        templateUrl: 'app/states/admin/groups/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Groups Create',
        resolve: {
          staff: resolveStaff
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
  function resolveStaff(Staff) {
    return Staff.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, Group, staff) {
    var vm = this;

    vm.title = 'Admin Group Create';
    vm.staff = staff;

    vm.activate = activate;

    activate();

    function activate() {
      initGroup();
      logger.info('Activated Admin Products Create View');
    }

    // Private

    function initGroup() {
      vm.group = Group.new();
    }
  }
})();
