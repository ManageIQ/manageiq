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

  /** @ngInject */
  function resolveService($stateParams, CollectionsApi) {
    return CollectionsApi.get('services', $stateParams.serviceId);
  }

  /** @ngInject */
  function StateController($state, service, CollectionsApi) {
    var vm = this;

    vm.title = 'Service Details';
    vm.service = service;

    vm.activate = activate;
    vm.removeService = removeService;

    activate();

    function activate() {
    }

    function removeService() {
      var removeAction = {'action': 'retire'};
      CollectionsApi.post('services', vm.service.id, {}, removeAction).then(removeSuccess, removeFailure);

      function removeSuccess() {
        $state.go('services.list');
      }

      function removeFailure(data) {
      }
    }
  }
})();
