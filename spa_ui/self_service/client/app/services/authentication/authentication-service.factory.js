(function() {
  'use strict';

  angular.module('app.services')
    .factory('AuthenticationService', AuthenticationServiceFactory);

  /** @ngInject */
  function AuthenticationServiceFactory($http, $q, $state, SessionService) {
    var service = {
      login: login,
      logout: logout,
      isAuthenticated: isAuthenticated,
      ssoInit: ssoInit
    };

    return service;

    function ssoInit() {
      var deferred = $q.defer();

      $http
        .get('/api/v1/saml/init')
        .success(samlSuccess)
        .error(samlError);

      return deferred.promise;

      function samlSuccess(response) {
        deferred.resolve(response.url);
      }

      function samlError() {
        deferred.resolve(false);
      }
    }

    function login(email, password) {
      var credentials = {
        staff: {
          email: email,
          password: password
        }
      };

      return $http
        .post('/api/v1/staff/sign_in', credentials)
        .success(loginSuccess);

      function loginSuccess(data) {
        SessionService.create(data);
      }
    }

    function logout() {
      return $http
        .delete('/api/v1/staff/sign_out')
        .success(logoutSuccess);

      function logoutSuccess() {
        SessionService.destroy();
      }
    }

    function isAuthenticated() {
      return !!SessionService.email;
    }
  }
})();
