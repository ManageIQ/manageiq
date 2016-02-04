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
        title: N_('Logout')
      }
    };
  }

  /** @ngInject */
  function StateController($state, Session) {
    var vm = this;

    vm.title = __('Logout');

    activate();

    function activate() {
      Session.destroy();
      $state.go('login');
    }
  }
})();
