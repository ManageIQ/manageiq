/* Help configure the state-base ui.router */
(function() {
  'use strict';

  angular.module('blocks.router')
    .provider('routerHelper', routerHelperProvider);

  /** @ngInject */
  function routerHelperProvider($locationProvider, $stateProvider, $urlRouterProvider, $injector) {
    /* jshint validthis:true */
    var config = {
      docTitle: undefined,
      resolveAlways: {}
    };

    var provider = {
      configure: configure,
      $get: RouterHelper
    };

    $locationProvider.html5Mode(true);

    return provider;

    function configure(cfg) {
      angular.extend(config, cfg);
    }

    /** @ngInject */
    function RouterHelper($location, $rootScope, $state, logger) {
      var handlingStateChangeError = false;
      var hasOtherwise = false;
      var stateCounts = {
        errors: 0,
        changes: 0
      };

      var service = {
        configureStates: configureStates,
        getStates: getStates,
        stateCounts: stateCounts
      };

      init();

      return service;

      function configureStates(states, otherwisePath) {
        angular.forEach(states, buildState);

        if (otherwisePath && !hasOtherwise) {
          hasOtherwise = true;
          $urlRouterProvider.otherwise(otherwisePath);
        }

        function buildState(stateConfig, state) {
          stateConfig.resolve = angular.extend(stateConfig.resolve || {}, config.resolveAlways);
          $stateProvider.state(state, stateConfig);
        }
      }

      function init() {
        // Route cancellation:
        // On routing error, go to the dashboard.
        // Provide an exit clause if it tries to do it twice.
        $rootScope.$on('$stateChangeError', handleRoutingErrors);
        $rootScope.$on('$stateChangeSuccess', updateTitle);
        // Hack in redirect to default children
        // Discussions: https://github.com/angular-ui/ui-router/issues/1235
        // https://github.com/angular-ui/ui-router/issues/27
        $rootScope.$on('$stateChangeStart', redirectTo);
      }

      function getStates() {
        return $state.get();
      }

      // Private

      function handleRoutingErrors(event, toState, toParams, fromState, fromParams, error) {
        var destination;
        var msg;

        if (handlingStateChangeError) {
          return;
        }
        stateCounts.errors++;
        handlingStateChangeError = true;
        destination = (toState && (toState.title || toState.name || toState.loadedTemplateUrl)) || 'unknown target';
        msg = 'Error routing to ' + destination + '. '
          + (error.data || '') + '. <br/>' + (error.statusText || '')
          + ': ' + (error.status || '');
        logger.warning(msg, [toState]);
        $location.path('/');
      }

      function updateTitle(event, toState) {
        stateCounts.changes++;
        handlingStateChangeError = false;
        $rootScope.title = config.docTitle + ' ' + (toState.title || ''); // data bind to <title>
      }

      function redirectTo(event, toState, toParams) {
        var redirect = toState.redirectTo;
        var newState;

        if (redirect) {
          if (angular.isString(redirect)) {
            event.preventDefault();
            $state.go(redirect, toParams);
          } else {
            newState = $injector.invoke(redirect, null, {toState: toState, toParams: toParams});
            if (newState) {
              if (angular.isString(newState)) {
                event.preventDefault();
                $state.go(newState);
              } else if (newState.state) {
                event.preventDefault();
                $state.go(newState.state, newState.params);
              }
            }
          }
        }
      }
    }
  }
})();
