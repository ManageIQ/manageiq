(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectMembershipTable', ProjectMembershipTableDirective);

  /** @ngInject */
  function ProjectMembershipTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        memberships: '=',
        groups: '=',
        roles: '='
      },
      link: link,
      templateUrl: 'app/components/project-membership-table/project-membership-table.html',
      controller: ProjectMembershipController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectMembershipController(lodash, Toasts, MembershipModal, Membership) {
      var vm = this;

      vm.activate = activate;
      vm.deleteGroup = deleteMembership;
      vm.showMembershipModal = showMembershipModal;
      vm.rowLookup = rowLookup;

      function activate() {
      }

      function deleteMembership(row) {
        new Membership(row).$delete(deleteSuccess, deleteError);

        function deleteSuccess() {
          lodash.remove(vm.memberships, {id: row.id});
          Toasts.toast('Group successfully removed.');
        }

        function deleteError() {
          Toasts.error('Could not remove group. Try again later.');
        }
      }

      function showMembershipModal(membership) {
        MembershipModal.showModal(membership).then(updateMembership);

        function updateMembership(result) {
          membership.role_id = result.role_id;
        }
      }

      function rowLookup(collection, itemId, itemKey) {
        return lodash.result(lodash.find(collection, {id: itemId}), itemKey);
      }
    }
  }
})();
