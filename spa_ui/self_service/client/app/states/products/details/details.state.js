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
      'products.details': {
        url: 'product/:productId',
        templateUrl: 'app/states/products/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Products Details'
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = 'Service Details';

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Products Details View');
    }
  }
})();
