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
      'order-history.list': {
        url: '', // No url, this state is the index of order-history
        templateUrl: 'app/states/order-history/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Order History'
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = 'Order History';
    activate();

    function activate() {
      logger.info('Activated Order History View');
    }
  }
})();
