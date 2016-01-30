(function() {
  'use strict';

  angular.module('app.resources')
    .factory('AuthenticationApi', AuthenticationApiFactory);

  /** @ngInject */
  function AuthenticationApiFactory($http, $base64, API_BASE, Session, Notifications) {
    var service = {
      login: login
    };

    return service;

    function login(userLogin, password) {
      return $http.get(API_BASE + '/api/auth?requester_type=ui', {
        headers: {
          'Authorization': 'Basic ' + $base64.encode([userLogin, password].join(':')),
          'X-Auth-Token': void 0
        }
      }).then(loginSuccess, loginFailure);

      function loginSuccess(response) {
        Session.create(response.data);
      }

      function loginFailure(response) {
        Session.destroy();
        Notifications.message('danger', '', 'Incorrect username or password.', false);

        return response;
      }
    }
  }
})();
