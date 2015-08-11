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
      'dashboard': {
        url: '/',
        templateUrl: 'app/states/dashboard/dashboard.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Dashboard'
      }
    };
  }

  function navItems() {
    return {
      'user': {
        type: 'dropdown',
        icon: 'fa-user',
        order: 0
      },
      'user.profile': {
        type: 'text',
        label: 'Profile',
        icon: 'fa.cog',
        order: 0
      },
      'user.logout': {
        type: 'text',
        label: 'Logout',
        icon: 'fa-logout',
        order: 1
      }
    };
  }

  function sidebarItems() {
    return {
      'dashboard': {
        type: 'state',
        state: 'dashboard',
        label: 'Dashboard',
        style: 'dashboard',
        order: 0
      }
    };
  }

  /** @ngInject */
  function StateController() {
    var vm = this;

    vm.title = 'Dashboard';

    activate();
    function activate() {
    }
  }
})();
