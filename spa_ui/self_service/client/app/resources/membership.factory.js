(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Membership', MembershipFactory);

  /** @ngInject */
  function MembershipFactory($resource) {
    var Membership = $resource('/api/v1/projects/:project_id/groups',
      {project_id: '@project_id', group_id: '@group_id'}, {
        update: {
          url: '/api/v1/projects/:project_id/groups/:group_id',
          method: 'PUT',
          isArray: false
        }
      });

    Membership.defaults = {
      project_id: null,
      group_id: null,
      role_id: null
    };

    Membership.new = newMembership;

    function newMembership(data) {
      return new Membership(angular.extend({}, Membership.defaults, data || {}));
    }

    return Membership;
  }
})();
