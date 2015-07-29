(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Role', RolesFactory);

  /** @ngInject */
  function RolesFactory($resource) {
    var Role = $resource('/api/v1/roles/:id', {id: '@id'}, {
      update: {
        method: 'PUT',
        isArray: false
      }
    });

    Role.defaults = {
      name: '',
      description: '',
      permissions: {approvals: [], projects: [], memberships: []}
    };

    Role.new = newRole;

    function newRole() {
      return new Role(angular.copy(Role.defaults));
    }

    return Role;
  }
})();
