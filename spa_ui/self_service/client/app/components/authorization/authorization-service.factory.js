(function() {
  'use strict';

  angular.module('app.components')
    .factory('AuthorizationService', AuthorizationServiceFactory);

  /** @ngInject */
  function AuthorizationServiceFactory(SessionService, userRoles, AuthenticationService) {
    var service = {
      isAuthorized: isAuthorized
    };

    return service;

    function isAuthorized(authorizedRoles) {
      if (!angular.isArray(authorizedRoles)) {
        authorizedRoles = [authorizedRoles];
      }
      // If authorizedRoles contains 'all', then we allow it through.
      if (authorizedRoles.indexOf(userRoles.all) !== -1) {
        return true;
      } else {
        return (AuthenticationService.isAuthenticated() && authorizedRoles.indexOf(SessionService.role) !== -1);
      }
    }
  }
})();
