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
      'logout': {
        url: '/logout',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Logout'
      }
    };
  }

  /** @ngInject */
  function StateController($state, AuthenticationService, logger, lodash) {
    var vm = this;

    vm.AuthService = AuthenticationService;
    vm.title = '';

    vm.AuthService.logout().success(lodash.bind(function() {
      logger.info('You have been logged out.');
      $state.transitionTo('login');
    }, vm)).error(lodash.bind(function() {
      logger.info('An error has occured at logout.');
    }, vm));
  }
})();
