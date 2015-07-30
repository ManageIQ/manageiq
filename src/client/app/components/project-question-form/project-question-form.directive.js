(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectQuestionForm', ProjectQuestionFormDirective);

  /** @ngInject */
  function ProjectQuestionFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        heading: '@?',
        projectQuestion: '='
      },
      link: link,
      templateUrl: 'app/components/project-question-form/project-question-form.html',
      controller: ProjectQuestionFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectQuestionFormController($state, Tag, ProjectQuestion, Toasts, TAG_QUERY_LIMIT, lodash) {
      var vm = this;

      var showValidationMessages = false;
      var home = 'admin.project-questions';

      vm.activate = activate;
      vm.backToList = backToList;
      vm.queryTags = queryTags;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;
      vm.typeChangeOk = typeChangeOk;
      vm.typeChangeCancel = typeChangeCancel;

      function activate() {
        vm.heading = vm.heading || 'Add Project Question';
      }

      function backToList() {
        $state.go(home);
      }

      function queryTags(query) {
        return Tag.query({q: query, limit: TAG_QUERY_LIMIT}).$promise;
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

        if (vm.form.$valid) {
          if (vm.projectQuestion.field_type !== 'select_option') {
            delete vm.projectQuestion.options;
          }
          if (vm.projectQuestion.id) {
            vm.projectQuestion.$update(saveSuccess, saveFailure);
          } else {
            vm.projectQuestion.$save(saveSuccess, saveFailure);
          }
        }

        return false;

        function saveSuccess() {
          Toasts.toast('Project Question saved.');
          $state.go(home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }

      function typeChangeOk() {
        vm.projectQuestion.options.length = 0;
        if (vm.projectQuestion.field_type === 'select_option') {
          vm.projectQuestion.options.push(angular.extend({}, ProjectQuestion.optionDefaults),
            angular.extend({}, ProjectQuestion.optionDefaults));
        }
      }

      function typeChangeCancel() {
      }
    }
  }
})();
