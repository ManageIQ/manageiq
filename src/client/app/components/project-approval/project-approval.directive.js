(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectApproval', ProjectApprovalDirective);

  /** @ngInject */
  function ProjectApprovalDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        project: '=',
        onApproved: '&?',
        onRejected: '&?'
      },
      link: link,
      templateUrl: 'app/components/project-approval/project-approval.html',
      controller: ProjectApprovalController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectApprovalController() {
      var vm = this;

      vm.message = '';

      vm.activate = activate;
      vm.approve = approve;
      vm.reject = reject;

      function activate() {
        vm.onApproved = angular.isDefined(vm.onApproved) ? vm.onApproved : angular.noop;
        vm.onRejected = angular.isDefined(vm.onRejected) ? vm.onRejected : angular.noop;
      }

      function approve() {
        vm.project.$approve(vm.onApproved);
      }

      function reject() {
        vm.project.$reject({reason: vm.message}, vm.onRejected);
      }
    }
  }
})();
