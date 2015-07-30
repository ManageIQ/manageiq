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
      'blank': {
        url: '/blank',
        templateUrl: 'app/states/blank/blank.html',
        controller: BlankController,
        controllerAs: 'vm',
        title: 'Blank',
        data: {
          layout: 'application'
        }
      }
    };
  }

  /** @ngInject */
  function BlankController(logger) {
    var vm = this;

    vm.title = 'Blank';

    activate();

    function activate() {
      logger.info('Activated Blank View');
    }
  }
})();
