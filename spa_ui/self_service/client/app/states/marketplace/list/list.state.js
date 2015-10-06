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
      'marketplace.list': {
        url: '',
        templateUrl: 'app/states/marketplace/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Catalog',
        resolve: {
          serviceTemplates: resolveServiceTemplates
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceTemplates(CollectionsApi) {
    var options = {expand: 'resources', filter: ['display=true'], attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.query('service_templates', options);
  }

  /** @ngInject */
  function StateController($state, serviceTemplates) {
    var vm = this;

    vm.title = 'Service Catalog';
    vm.serviceTemplates = serviceTemplates.resources;

    vm.showDetails = showDetails;

    function showDetails(template) {
      $state.go('marketplace.details', {serviceTemplateId: template});
    }
  }
})();
