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
      'order-history.details': {
        url: '/:id',
        templateUrl: 'app/states/order-history/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Order History Details'
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = 'Order History Details';

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Order History Details View');
    }
  }
})();
