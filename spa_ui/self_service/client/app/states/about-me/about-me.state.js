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
      'about-me': {
        url: '/',
        templateUrl: 'app/states/about-me/about-me.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'About Me'
      }
    };
  }

  /** @ngInject */
  function StateController() {
    var vm = this;

    vm.title = 'About Me';
  }
})();
