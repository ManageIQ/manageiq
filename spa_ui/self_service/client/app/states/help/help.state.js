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
      'help': {
        url: '/',
        templateUrl: 'app/states/help/help.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Help'
      }
    };
  }

  /** @ngInject */
  function StateController() {
    var vm = this;

    vm.title = 'Help';
  }
})();
