(function() {
  'use strict';

  angular.module('app.components')
    .directive('groupsTable', GroupsTableDirective);

  /** @ngInject */
  function GroupsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        groups: '='
      },
      link: link,
      templateUrl: 'app/components/groups-table/groups-table.html',
      controller: GroupsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function GroupsTableController(lodash, Group, Toasts) {
      var vm = this;

      vm.activate = activate;
      vm.deleteGroup = deleteGroup;

      function activate() {
      }

      function deleteGroup(index) {
        var group = vm.groups[index];

        if (!group) {
          return;
        }

        lodash.remove(vm.groups, {id: group.id});
        group.$delete(deleteSuccess, deleteError);

        function deleteSuccess() {
          Toasts.toast('Group deleted.');
        }

        function deleteError() {
          Toasts.error('Could not delete group. Try again later.');
          vm.groups.splice(index, 0, group);
        }
      }
    }
  }
})();
