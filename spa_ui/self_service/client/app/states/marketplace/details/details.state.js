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
      'marketplace.details': {
        url: '/:serviceTemplateId',
        templateUrl: 'app/states/marketplace/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Template Details',
        resolve: {
          serviceTemplate: resolveServiceTemplate
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceTemplate($stateParams, CollectionsApi) {
    return CollectionsApi.get('service_templates', $stateParams.serviceTemplateId);
  }

  /** @ngInject */
  function StateController(serviceTemplate) {
    var vm = this;

    vm.title = 'Service Template Details';
    vm.serviceTemplate = serviceTemplate;
  }
})();
