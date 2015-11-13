(function() {
  'use strict';

  angular.module('app.services')
    .factory('Session', SessionFactory);

  /** @ngInject */
  function SessionFactory($http, moment) {
    var model = {
      token: null,
      expiresOn: moment().subtract(1, 'seconds'),
      user: {}
    };

    var service = {
      current: model,
      create: create,
      destroy: destroy,
      active: active,
      currentUser: currentUser
    };

    destroy();

    return service;

    function create(data) {
      model.token = data.auth_token;
      model.expiresOn = moment(data.expires_on);
      $http.defaults.headers.common['X-Auth-Token'] = model.token;
    }

    function destroy() {
      model.token = null;
      model.expiresOn = moment().subtract(1, 'seconds');
      model.user = {};
      delete $http.defaults.headers.common['X-Auth-Token'];
    }

    function currentUser(user) {
      if (angular.isDefined(user)) {
        model.user = user;
      }

      return model.user;
    }

    // Helpers

    function active() {
      return model.token && model.expiresOn.isAfter();
    }
  }
})();
