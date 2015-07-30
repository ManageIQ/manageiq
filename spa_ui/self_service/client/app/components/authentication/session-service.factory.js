(function() {
  'use strict';

  angular.module('app.components')
    .factory('SessionService', SessionServiceFactory);

  /** @ngInject */
  function SessionServiceFactory() {
    var service = {
      create: create,
      destroy: destroy,
      fullName: fullName
    };

    destroy();

    return service;

    function create(data) {
      service.id = data.id;
      service.firstName = data.first_name;
      service.lastName = data.last_name;
      service.email = data.email;
      service.role = data.role;
      service.updatedAt = data.updated_at;
    }

    function destroy() {
      service.id = null;
      service.firstName = null;
      service.lastName = null;
      service.email = null;
      service.role = null;
      service.updatedAt = null;
    }

    // Helpers

    function fullName() {
      return [service.firstName, service.lastName].join(' ');
    }
  }
})();
