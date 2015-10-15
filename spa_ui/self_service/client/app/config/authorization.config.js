(function() {
  'use strict';

  angular.module('app.services')
    .config(configure)
    .run(init);

  /** @ngInject */
  function configure($httpProvider) {
    $httpProvider.interceptors.push(interceptor);

    /** @ngInject */
    function interceptor($injector, $q) {
      return {
        response: response,
        responseError: responseError
      };

      function response(res) {
        if (401 === res.status) {
          endSession();

          return $q.reject(res);
        }

        return $q.resolve(res);
      }

      function responseError(rej) {
        if (401 === rej.status) {
          endSession();

          return $q.reject(rej);
        }

        return $q.reject(rej);
      }

      function endSession() {
        var $state = $injector.get('$state');

        if ('login' !== $state.current.name) {
          $injector.get('Notifications').message('danger', '', 'Your session has timed out.', true);
          $injector.get('Session').destroy();
          $state.go('login');
        }
      }
    }
  }

  /** @ngInject */
  function init($rootScope, $state, Session, jQuery) {
    $rootScope.$on('$stateChangeStart', changeStart);
    $rootScope.$on('$stateChangeError', changeError);
    $rootScope.$on('$stateChangeSuccess', changeSuccess);

    function changeStart(event, toState, toParams, fromState, fromParams) {
      if (toState.data && !toState.data.requireUser) {
        return;
      }

      if (!Session.active()) {
        event.preventDefault();
        $state.transitionTo('login');
      }
    }

    function changeError(event, toState, toParams, fromState, fromParams, error) {
      // If a 401 is encountered during a state change, then kick the user back to the login
      if (401 === error.status) {
        event.preventDefault();
        if (Session.active()) {
          $state.transitionTo('logout');
        } else if ('login' !== toState.name) {
          $state.transitionTo('login');
        }
      }
    }

    function changeSuccess() {
      jQuery('html, body').animate({scrollTop: 0}, 200);
    }
  }
})();
