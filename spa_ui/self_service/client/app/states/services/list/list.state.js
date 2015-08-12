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
      'services.list': {
        url: '', // No url, this state is the index of projects
        templateUrl: 'app/states/services/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Services'
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    /* jshint validthis: true */
    var vm = this;

    vm.title = 'Services';

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Service View');
    }
  }
})();
