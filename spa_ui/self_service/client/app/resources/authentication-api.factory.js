(function() {
  'use strict';

  angular.module('app.resources')
    .factory('AuthenticationApi', AuthenticationApiFactory);

  /** @ngInject */
  function AuthenticationApiFactory($timeout, $http, $base64, API_BASE, Session, moment) {
    var service = {
      login: login,
      logout: logout
    };

    // Hold on to the credentials so that the token can be refreshed
    var credentials = {
      login: '',
      password: ''
    };

    var refresh = null;

    return service;

    function login(userLogin, password) {
      credentials.login = userLogin;
      credentials.password = password;

      return doLogin();
    }

    function logout() {
      return $http
        .delete('/api/logout')
        .success(logoutSuccess);

      function logoutSuccess() {
        if (refresh) {
          refresh.cancel();
        }
        credentials = {
          login: '',
          password: ''
        };
        Session.destroy();
      }
    }

    // Private

    function doLogin() {
      return $http.get(API_BASE + '/api/auth', {
        headers: {
          'Authorization': 'Basic ' + $base64.encode([credentials.login, credentials.password].join(':')),
          'X-Auth-Token': void 0
        }
      }).then(loginSuccess, loginFailure);

      function loginSuccess(response) {
        Session.create(response.data);
        // Hack; Re-authenticate a little before the token expires to keep it fresh
        refresh = $timeout(doLogin, Session.current.expiresOn.subtract(30, 'seconds').diff(moment()));
      }

      function loginFailure(response) {
        Session.destroy();
        console.log('TODO: Unhandled loginFailure', response.data);
      }
    }
  }
})();
