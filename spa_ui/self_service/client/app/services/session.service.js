(function() {
  'use strict';

  angular.module('app.services')
    .factory('Session', SessionFactory);

  /** @ngInject */
  function SessionFactory($http, moment, $sessionStorage) {
    var model = {
      token: null,
      user: {}
    };

    var service = {
      current: model,
      create: create,
      destroy: destroy,
      active: active,
      currentUser: currentUser,
      loadUser: loadUser,
    };

    destroy();

    return service;

    function create(data) {
      model.token = data.auth_token;
      $http.defaults.headers.common['X-Auth-Token'] = model.token;
      $sessionStorage.token = model.token;
    }

    function destroy() {
      model.token = null;
      model.user = {};
      delete $http.defaults.headers.common['X-Auth-Token'];
      delete $sessionStorage.token;
    }

    function loadUser() {
      return $http.get('/api')
        .then(function(response) {
          currentUser(response.data.identity);
        });
    }

    function currentUser(user) {
      if (angular.isDefined(user)) {
        model.user = user;
      }

      return model.user;
    }

    // Helpers

    function active() {
      // may not be current, but if we have one, we'll rely on API 401ing if it's not
      return model.token;
    }
  }
})();
