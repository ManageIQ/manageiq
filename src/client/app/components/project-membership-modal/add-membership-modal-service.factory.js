(function() {
  'use strict';

  angular.module('app.components')
    .factory('MembershipModal', ProjectMembershipFactory);

  /** @ngInject */
  function ProjectMembershipFactory($modal, Group, Role) {
    var service = {
      showModal: showModal
    };

    return service;

    function showModal(membership) {
      var modalOptions = {
        templateUrl: 'app/components/project-membership-modal/add-membership-modal.html',
        controller: AddMembershipModalController,
        controllerAs: 'vm',
        resolve: {
          groups: resolveGroups,
          roles: resolveRoles,
          membership: resolveMembership
        },
        windowTemplateUrl: 'app/components/project-membership-modal/add-membership-modal-window.html'
      };
      var modal = $modal.open(modalOptions);

      return modal.result;

      function resolveMembership() {
        return membership;
      }

      function resolveGroups() {
        return Group.query().$promise;
      }

      function resolveRoles() {
        return Role.query().$promise;
      }
    }
  }

  /** @ngInject */
  function AddMembershipModalController(groups, roles, membership, Toasts, $modalInstance) {
    var vm = this;

    vm.groups = groups;
    vm.membership = membership;
    vm.roles = roles;
    vm.onSubmit = onSubmit;
    vm.showErrors = showErrors;
    vm.hasErrors = hasErrors;

    activate();

    function activate() {
    }

    function onSubmit() {
      vm.showValidationMessages = true;

      if (vm.form.$valid) {
        if (vm.membership.id) {
          vm.membership.$update(updateSuccess, updateFailure);
        } else {
          vm.membership.$save(saveSuccess, saveFailure);
        }
      }

      function saveSuccess() {
        $modalInstance.close(vm.membership);
        Toasts.toast('Group successfully added.');
      }

      function saveFailure() {
        Toasts.error('Server returned an error while saving.');
      }

      function updateSuccess() {
        $modalInstance.close(vm.membership);
        Toasts.toast('Group successfully updated.');
      }

      function updateFailure() {
        Toasts.error('Server returned an error while updating.');
      }
    }

    function showErrors() {
      return vm.showValidationMessages;
    }

    function hasErrors(field) {
      if (angular.isUndefined(field)) {
        return vm.showValidationMessages && vm.form.$invalid;
      }

      return vm.showValidationMessages && vm.form[field].$invalid;
    }
  }
})();
