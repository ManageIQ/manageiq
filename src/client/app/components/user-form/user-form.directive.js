(function() {
  'use strict';

  angular.module('app.components')
    .directive('userForm', UserFormDirective);

  /** @ngInject */
  function UserFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        userToEdit: '=?',
        editing: '=?'
      },
      link: link,
      templateUrl: 'app/components/user-form/user-form.html',
      controller: UserFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function UserFormController($scope, $state, Toasts, Staff, lodash) {
      var vm = this;

      vm.activate = activate;
      activate();

      vm.showValidationMessages = false;
      vm.home = 'admin.users.list';
      vm.format = 'yyyy-MM-dd';
      vm.filteredProject = lodash.omit(vm.userToEdit, 'created_at', 'updated_at', 'deleted_at');
      vm.backToList = backToList;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;

      function activate() {
      }

      function backToList() {
        $state.go(vm.home);
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
        // This is so errors can be displayed for 'untouched' angular-schema-form fields
        $scope.$broadcast('schemaFormValidate');
        if (vm.form.$valid) {
          if (vm.editing) {
            for (var prop in vm.userToEdit) {
              if (vm.filteredProject[prop] === null) {
                delete vm.filteredProject[prop];
              }
            }
            Staff.update(vm.filteredProject).$promise.then(saveSuccess, saveFailure);

            return false;
          } else {
            Staff.save(vm.userToEdit).$promise.then(saveSuccess, saveFailure);

            return false;
          }
        }

        function saveSuccess() {
          Toasts.toast('User saved.');
          $state.go(vm.home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }
    }
  }
})();
