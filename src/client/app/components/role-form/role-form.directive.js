(function() {
  'use strict';

  angular.module('app.components')
    .directive('roleForm', RoleFormDirective);

  /** @ngInject */
  function RoleFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        role: '=',
        heading: '@'
      },
      link: link,
      templateUrl: 'app/components/role-form/role-form.html',
      controller: RoleFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function RoleFormController($scope, $state, Toasts, lodash, Role) {
      var vm = this;

      vm.activate = activate;
      activate();

      vm.home = 'admin.roles.list';
      vm.showValidationMessages = false;

      vm.backToList = backToList;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;

      function activate() {
        initPermissions();
      }

      function backToList() {
        $state.go(vm.home);
      }

      function initPermissions() {
        vm.permissions = Role.new().permissions;
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

      function onSubmit() {
        vm.showValidationMessages = true;

        if (vm.form.$valid) {
          if (vm.role.id) {
            vm.role.$update(saveSuccess, saveFailure);
          } else {
            vm.role.$save(saveSuccess, saveFailure);
          }
        }

        function saveSuccess() {
          Toasts.toast('Role saved.');
          $state.go(vm.home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }
    }
  }
})();
