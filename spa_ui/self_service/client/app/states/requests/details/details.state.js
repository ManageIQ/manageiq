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
      'requests.details': {
        url: '/:requestId',
        templateUrl: 'app/states/requests/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Requests Details',
        resolve: {
          request: resolveRequest
        }
      }
    };
  }

  /** @ngInject */
  function resolveRequest($stateParams, CollectionsApi) {
    return CollectionsApi.get('provision_requests', $stateParams.requestId);
  }

  /** @ngInject */
  function StateController(request) {
    var vm = this;

    vm.title = 'Service Template Details';
    vm.request = request;
  }
})();
