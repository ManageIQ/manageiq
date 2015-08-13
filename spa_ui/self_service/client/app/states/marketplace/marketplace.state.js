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
      'marketplace': {
        url: '/marketplace?tags',
        templateUrl: 'app/states/marketplace/marketplace.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Marketplace',
        reloadOnSearch: false
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = 'Marketplace';

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Marketplace View');
    }
  }
})();
