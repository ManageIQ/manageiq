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
        url: '/dashboard',
        templateUrl: 'app/states/dashboard/dashboard.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Dashboard'
      }
    };
  }

  function navItems() {
    return {
      'profile': {
        type: 'profile',
        order: 0
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
  function StateController(Dashboard, logger) {
    var vm = this;

    vm.title = 'Dashboard';
    vm.onDropComplete = onDropComplete;

    activate();
    function activate() {
      vm.chartCollection = Dashboard;
      logger.info('Activated Dashboard View');
    }

    function onDropComplete(index, obj) {
      vm.secondObj = vm.chartCollection[index];
      vm.secondIndex = vm.chartCollection.indexOf(obj);
      vm.chartCollection[index] = obj;
      vm.chartCollection[vm.secondIndex] = vm.secondObj;
    }
  }
})();
