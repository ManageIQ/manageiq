(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectFormOptions', ProjectFormOptionsDirective);

  /** @ngInject */
  function ProjectFormOptionsDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        projectOptions: '='
      },
      link: link,
      templateUrl: 'app/components/project-form/project-form-options.html',
      controller: ProjectFormOptionsController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectFormOptionsController() {
      var vm = this;

      var showValidationMessages = false;

      vm.activate = activate;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.format = 'yyyy-MM-dd';
      vm.dateOptions = {
        formatYear: 'yy',
        startingDay: 0,
        showWeeks: false
      };
      vm.openStart = openStart;
      vm.openEnd = openEnd;
      vm.openAnswerDate = openAnswerDate;

      function activate() {
      }

      function showErrors() {
        return showValidationMessages;
      }

      function hasErrors(field) {
        if (angular.isUndefined(field)) {
          return showValidationMessages && vm.form.$invalid;
        }

        return showValidationMessages && vm.form[field].$invalid;
      }

      function openStart($event) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.openedStart = true;
      }

      function openEnd($event) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.openedEnd = true;
      }

      function openAnswerDate($event, index) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.startDateOpened = false;
        vm.endDateOpened = false;
        vm.answerDateOpened = [];
        vm.answerDateOpened[index] = true;
      }
    }
  }
})();
