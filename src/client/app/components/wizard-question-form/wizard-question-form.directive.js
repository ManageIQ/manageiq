(function() {
  'use strict';

  angular.module('app.components')
    .directive('wizardQuestionForm', WizardQuestionFormDirective);

  /** @ngInject */
  function WizardQuestionFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        heading: '@?',
        question: '='
      },
      link: link,
      templateUrl: 'app/components/wizard-question-form/wizard-question-form.html',
      controller: WizardQuestionFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function WizardQuestionFormController($state, Tag, WizardQuestion, Toasts, TAG_QUERY_LIMIT) {
      var vm = this;

      var showValidationMessages = false;
      var home = 'admin.wizard-questions';

      vm.activate = activate;
      vm.backToList = backToList;
      vm.queryTags = queryTags;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;
      vm.typeChangeOk = typeChangeOk;
      vm.typeChangeCancel = typeChangeCancel;

      function activate() {
        vm.heading = vm.heading || 'Add A Wizard Question';
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
          if (vm.question.id) {
            vm.question.$update(saveSuccess, saveFailure);
          } else {
            vm.question.$save(saveSuccess, saveFailure);
          }
        }

        function saveSuccess() {
          Toasts.toast('Wizard Question saved.');
          $state.go(home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }

      function typeChangeOk() {
        vm.question.options.length = 0;
        vm.question.options.push(angular.extend({}, WizardQuestion.optionDefaults));
        vm.question.options.push(angular.extend({}, WizardQuestion.optionDefaults));
      }

      function typeChangeCancel() {
        vm.question.type = 'multiple' === vm.question.type ? 'yes_no' : 'multiple';
      }
    }
  }
})();
