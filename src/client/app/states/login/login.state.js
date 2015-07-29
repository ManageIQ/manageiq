(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper, navigationHelper) {
    routerHelper.configureStates(getStates());
    navigationHelper.navItems(navItems());
  }

  function navItems() {
    return {};
  }

  function getStates() {
    return {
      'login': {
        url: '/',
        templateUrl: 'app/states/login/login.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Login',
        resolve: {
          motd: resolveMotd
        },
        data: {
          layout: 'blank'
        }
      }
    };
  }

  /** @ngInject */
  function resolveMotd(Motd) {
    return Motd.get().$promise;
  }

  /** @ngInject */
  function StateController(motd) {
    var vm = this;

    vm.title = 'Login';
    vm.motd = motd;
    activate();

    function activate() {
    }
  }
})();
