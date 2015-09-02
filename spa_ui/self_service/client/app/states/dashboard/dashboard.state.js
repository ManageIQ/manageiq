(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'dashboard': {
        parent: 'application',
        url: '/',
        templateUrl: 'app/states/dashboard/dashboard.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Dashboard',
        data: {
          requireUser: true
        },
        resolve: {
          requests: resolveRequests,
          services: resolveServices
        }
      }
    };
  }

  /** @ngInject */
  function resolveRequests(CollectionsApi) {
    return CollectionsApi.query('provision_requests');
  }

  /** @ngInject */
  function resolveServices(CollectionsApi) {
    var options = {expand: false};

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function StateController(services, requests) {
    var vm = this;
    vm.servicesCount = services.count;
    vm.requestsCount = requests.count;
    vm.title = 'Dashboard';
  }
})();
