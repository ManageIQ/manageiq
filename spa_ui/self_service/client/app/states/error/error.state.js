(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    var otherwise = '/error';
    routerHelper.configureStates(getStates(), otherwise);
  }

  function getStates() {
    return {
      'error': {
        url: '/error',
        templateUrl: 'app/states/error/error.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Error',
        data: {
          layout: 'blank'
        },
        params: {
          error: null
        }
      }
    };
  }

  /** @ngInject */
  function StateController($stateParams) {
    var vm = this;

    vm.error = $stateParams.error;
  }
})();
