(function() {
  'use strict';

  angular.module('app.components')
    .run(startup);

  /** @ngInject */
  function startup(Staff, $state, SessionService) {
    var dashboard = 'dashboard';
    var login = 'login';

    Staff.getCurrentMember(startupSuccess, startupError);

    function startupSuccess(data) {
      SessionService.create(data);
      $state.go(dashboard);
    }

    function startupError() {
      $state.go(login);
    }
  }
})();
