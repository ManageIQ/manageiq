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
      'admin.alerts.edit': {
        url: '/edit/:id',
        templateUrl: 'app/states/admin/alerts/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Alerts Create',
        resolve: {
          alertRecord: resolveAlert,
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
  function resolveAlert($stateParams, Alert) {
    if ($stateParams.id) {
      return Alert.get({id: $stateParams.id}).$promise;
    } else {
      return {};
    }
  }

  /** @ngInject */
  function resolveStaff(Staff) {
    return Staff.getCurrentMember().$promise;
  }

  /** @ngInject */
  function StateController(logger, alertRecord, $stateParams, staff) {
    var vm = this;

    vm.title = 'Admin Alerts Edit';
    vm.alertRecord = alertRecord;
    vm.activate = activate;
    vm.staffId = staff.id;
    vm.home = 'admin.alerts.list';
    vm.homeParams = { };

    // HARD CODED FOR SINGLE TENANT
    vm.alertableType = 'Organization';
    vm.alertableId = '1';

    activate();

    function activate() {
      logger.info('Activated Admin Alerts Create View');
    }
  }
})();
