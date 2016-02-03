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
        title: N_('Products Details')
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = __('Service Details');

    vm.activate = activate;

    activate();

    function activate() {
      logger.info(__('Activated Products Details View'));
    }
  }
})();
