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
      'services.details': {
        url: '/:serviceId',
        templateUrl: 'app/states/services/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Details',
        resolve: {
          service: resolveService
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
  function resolveService(Service, $stateParams) {
    return Service.get({id: $stateParams.serviceId, 'includes[]': ['product', 'project', 'latest_alerts']}).$promise;
  }

  /** @ngInject */
  function StateController(logger, service, $stateParams) {
    var vm = this;

    vm.title = 'Service Details';

    vm.serviceId = $stateParams.serviceId;
    vm.service = service;

    vm.activate = activate;
    vm.toAlertType = toAlertType;

    activate();

    function activate() {
      logger.info('Activated Service Details View');
    }

    function toAlertType(type) {
      switch (type.toLowerCase()) {
        case 'critical':
          return 'danger';
        case 'warning':
          return 'warning';
        case 'ok':
          return 'success';
        default:
          return 'info';
      }
    }
  }
})();
