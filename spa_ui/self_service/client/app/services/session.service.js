(function() {
  'use strict';

  angular.module('app.services')
    .factory('Session', SessionFactory);

  /** @ngInject */
  function SessionFactory(moment) {
    var model = {
      token: null,
      expiresOn: moment().subtract(1, 'seconds')
    };

    var service = {
      current: model,
      create: create,
      destroy: destroy,
      active: active
    };

    destroy();

    return service;

    function create(data) {
      model.token = data.auth_token;
      model.expiresOn = moment(data.expires_on);
    }

    function destroy() {
      model.token = null;
      model.expiresOn = moment().subtract(1, 'seconds');
    }

    // Helpers

    function active() {
      return model.token && model.expiresOn.isAfter();
    }
  }
})();
