(function() {
  'use strict';

  angular.module('app.services')
    .run(appRun);

  /** @ngInject */
  function appRun($rootScope, $state, AuthenticationService, logger, jQuery) {
    activate();

    function activate() {
    }

    // catch any error in resolve in state
    $rootScope.$on('$stateChangeError', function(event, toState, toParams, fromState, fromParams, error) {
      // If a 401 is encountered during a state change, then kick the user back to the login
      if (401 === error.status) {
        if (AuthenticationService.isAuthenticated()) {
          $state.transitionTo('logout');
        } else if ('login' !== toState.name) {
          $state.transitionTo('login');
        }
      } else if (403 === error.status) {
        logger.error('An error has prevent the page from loading. Please try again later.');
        if ('dashboard' !== fromState.name) {
          $state.transitionTo('dashboard');
        }
      } else {
        $state.go('error', { error: error });
        logger.error('Unhandled State Change Error occurred: ' + (error.statusText || error.message));
      }
      event.preventDefault();
    });

    $rootScope.$on('$stateChangeSuccess', function() {
      jQuery('html, body').animate({ scrollTop: 0 }, 200);
    });

    $rootScope.$on('$stateNotFound', function(event) {
      event.preventDefault();
    });
  }
})();
