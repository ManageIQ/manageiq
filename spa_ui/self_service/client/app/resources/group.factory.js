(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Group', GroupFactory);

  /** @ngInject */
  function GroupFactory($resource) {
    var Group = $resource('/api/v1/groups/:id', {id: '@id'}, {
      update: {
        method: 'PUT',
        isArray: false
      }
    });

    Group.defaults = {
      name: '',
      description: '',
      staff_ids: []
    };

    Group.new = newGroup;

    function newGroup() {
      return new Group(angular.copy(Group.defaults));
    }

    return Group;
  }
})();
