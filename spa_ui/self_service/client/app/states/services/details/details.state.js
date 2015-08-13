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
      'services.details': {
        url: '/:serviceId',
        templateUrl: 'app/states/services/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Details'
      }
    };
  }

  /** @ngInject */
  function StateController(logger) {
    var vm = this;

    vm.title = 'Service Details';

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Service Details View');
    }
  }
})();
