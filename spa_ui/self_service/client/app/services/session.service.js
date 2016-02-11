(function() {
  'use strict';

  angular.module('app.services')
    .factory('Session', SessionFactory);

  /** @ngInject */
  function SessionFactory($http, moment, $sessionStorage, gettextCatalog, $window, $state) {
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
      switchGroup: switchGroup,
    };

    destroy();

    return service;

    function create(data) {
      model.token = data.auth_token;
      $http.defaults.headers.common['X-Auth-Token'] = model.token;
      $http.defaults.headers.common['X-Miq-Group'] = data.miqGroup || undefined;
      $sessionStorage.token = model.token;
      $sessionStorage.miqGroup = data.miqGroup || null;
    }

    function destroy() {
      model.token = null;
      model.user = {};
      delete $http.defaults.headers.common['X-Auth-Token'];
      delete $http.defaults.headers.common['X-Miq-Group'];
      delete $sessionStorage.miqGroup;
      delete $sessionStorage.token;
    }

    function loadUser() {
      return $http.get('/api')
        .then(function(response) {
          currentUser(response.data.identity);

          var locale = response.data.settings && response.data.settings.locale;
          gettextCatalog.loadAndSet(locale);
        });
    }

    function currentUser(user) {
      if (angular.isDefined(user)) {
        model.user = user;
      }

      return model.user;
    }

    function switchGroup(group) {
      $sessionStorage.miqGroup = group;

      // reload .. but on dashboard
      $window.location.href = $state.href('dashboard');
    }

    // Helpers

    function active() {
      // may not be current, but if we have one, we'll rely on API 401ing if it's not
      return model.token;
    }
  }
})();
