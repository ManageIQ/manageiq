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
          serviceCatalogs: resolveServiceCatalogs
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceCatalogs(CollectionsApi) {
    var options = {expand: ['resources', 'service_templates']};

    return CollectionsApi.query('service_catalogs', options);
  }

  /** @ngInject */
  function StateController($state, serviceCatalogs) {
    var vm = this;

    vm.title = 'Service Catalog';
    vm.serviceCatalogs = serviceCatalogs.resources;

    vm.showDetails = showDetails;

    function showDetails(templateId) {
      $state.go('marketplace.details', {serviceTemplateId: templateId});
    }
  }
})();
