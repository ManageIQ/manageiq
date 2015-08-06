(function() {
  'use strict';

  angular.module('app.components')
    .directive('groupForm', GroupFormDirective);

  /** @ngInject */
  function GroupFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        group: '=',
        staff: '=',
        heading: '@'
      },
      link: link,
      templateUrl: 'app/components/group-form/group-form.html',
      controller: GroupFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function GroupFormController($scope, $state, Toasts, Staff, lodash) {
      var vm = this;

      vm.activate = activate;
      activate();

      vm.home = 'admin.groups.list';
      vm.showValidationMessages = false;

      vm.format = 'yyyy-MM-dd';

      vm.addMember = addMember;
      vm.removeMember = removeMember;

      vm.backToList = backToList;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;

      function activate() {
        initMembers();
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

        if (vm.form.$valid) {
          if (vm.group.id) {
            vm.group.$update(saveSuccess, saveFailure);
          } else {
            vm.group.$save(saveSuccess, saveFailure);
          }
        }

        function saveSuccess() {
          Toasts.toast('Group saved.');
          $state.go(vm.home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }

      function addMember(staffId) {
        var staff = lodash.find(vm.staff, {id: staffId});

        if (!staff) {
          return;
        }

        if (!lodash.find(vm.members, {id: staffId})) {
          vm.members.push(staff);
        }

        if (-1 === vm.group.staff_ids.indexOf(staffId)) {
          vm.group.staff_ids.push(staffId);
        }

        vm.selectedStaff = null;
      }

      function removeMember(staffId) {
        lodash.remove(vm.members, {id: staffId});
        lodash.pull(vm.group.staff_ids, staffId);
      }

      // Private

      function initMembers() {
        vm.members = [];
        angular.forEach(vm.group.staff_ids, addMember);
      }
    }
  }
})();
