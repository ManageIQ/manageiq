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
      'admin.alerts.list': {
        url: '', // No url, this state is the index of admin.alerts
        templateUrl: 'app/states/admin/alerts/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Alerts List',
        resolve: {
          alerts: resolveAlerts
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
  function resolveAlerts(Alert) {
    return Alert.query({latest: 'true', alertable_type: 'Organization'}).$promise;
  }

  /** @ngInject */
  function StateController(lodash, logger, $q, $state, alerts, Toasts) {
    var vm = this;

    vm.title = 'Admin Products List';
    vm.alerts = alerts;

    vm.activate = activate;
    vm.goTo = goTo;
    activate();

    function activate() {
      logger.info('Activated Admin Products List View');
    }

    function goTo(id) {
      $state.go('admin.alerts.create', {alertId: id});
    }

    vm.deleteAlert = deleteAlert;

    function deleteAlert(alert) {
      alert.$delete(deleteSuccess, deleteFailure);

      function deleteSuccess() {
        lodash.remove(vm.alerts, {id: alert.id});
        Toasts.toast('Alert deleted.');
      }

      function deleteFailure() {
        Toasts.error('Server returned an error while deleting.');
      }
    }
  }
})();
