(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectForm', ProjectFormDirective);

  /** @ngInject */
  function ProjectFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        project: '=',
        heading: '@?'
      },
      link: link,
      templateUrl: 'app/components/project-form/project-form.html',
      controller: ProjectFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectFormController($scope, $state, Toasts, Project, lodash) {
      var vm = this;

      var showValidationMessages = false;
      vm.format = 'yyyy-MM-dd';
      vm.dateOptions = {
        formatYear: 'yy',
        startingDay: 0,
        showWeeks: false
      };

      vm.activate = activate;
      activate();

      vm.backToList = backToList;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;
      vm.openStart = openStart;
      vm.openEnd = openEnd;
      vm.openAnswerDate = openAnswerDate;

      function activate() {
      }

      function backToList() {
        if (vm.project.id) {
          $state.go('projects.details', {projectId: vm.project.id});
        } else {
          $state.go('^');
        }
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

      function onSubmit() {
        showValidationMessages = true;
        // This is so errors can be displayed for 'untouched' angular-schema-form fields
        $scope.$broadcast('schemaFormValidate');
        if (vm.form.$valid) {
          // If editing update rather than save
          if (vm.project.id) {
            vm.filteredProject = lodash.omit(vm.project, 'created_at', 'updated_at', 'deleted_at', 'services', 'domain',
              'url', 'state', 'state_ok', 'problem_count', 'account_number', 'resources', 'icon', 'status', 'users',
              'order_history', 'cc', 'staff_id', 'approved', 'project_answers');
            if (angular.isDefined(vm.project.project_answers) && (vm.project.project_answers.length > 0)) {
              vm.filteredProject.project_answers = lodash.map(
                vm.project.project_answers, projectAnswerReduction);
            }
            Project.update(vm.filteredProject).$promise.then(saveSuccess, saveFailure);

            return false;
          } else {
            Project.save(vm.project).$promise.then(saveSuccess, saveFailure);

            return false;
          }
        }

        function projectAnswerReduction(item) {
          return {id: item.id, project_question_id: item.project_question.id, answer: item.answer};
        }

        function saveSuccess() {
          Toasts.toast(vm.project.name + ' saved to projects.');
          vm.backToList();
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
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
