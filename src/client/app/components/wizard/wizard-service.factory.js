(function() {
  'use strict';

  angular.module('app.components')
    .factory('WizardService', WizardServiceFactory);

  /** @ngInject */
  function WizardServiceFactory($modal, WizardQuestion) {
    var service = {
      showModal: showModal
    };

    return service;

    function showModal() {
      var modalOptions = {
        templateUrl: 'app/components/wizard/wizard-modal.html',
        controller: WizardModalController,
        controllerAs: 'vm',
        resolve: {
          questions: resolveQuestions
        },
        windowTemplateUrl: 'app/components/wizard/wizard-modal-window.html'
      };
      var modal = $modal.open(modalOptions);

      return modal.result;

      function resolveQuestions() {
        return WizardQuestion.query().$promise;
      }
    }
  }

  /** @ngInject */
  function WizardModalController(questions, lodash) {
    var vm = this;

    vm.state = 'intro';
    vm.questions = questions;
    vm.question = null;
    vm.questionPointer = 0;
    vm.answeredQuestions = [];

    vm.startWizard = startWizard;
    vm.answerWith = answerWith;
    vm.questionNavigation = questionNavigation;

    activate();

    function activate() {
    }

    function startWizard() {
      vm.question = vm.questions[vm.questionPointer];
      vm.state = 'wizard';
    }

    function answerWith(index) {
      if (0 <= index) {
        vm.answeredQuestions[vm.questionPointer] = vm.question.wizard_answers[index];
      } else {
        vm.answeredQuestions[vm.questionPointer] = -1;
      }

      if (vm.questionPointer < vm.questions.length - 1) {
        vm.questionNavigation(1);
      } else {
        lodash.forEach(vm.answeredQuestions, parseQuestionAnswers);
        vm.state = 'complete';
      }
    }

    function parseQuestionAnswers(item) {
      if (item === -1) {
        return;
      } else {
        vm.tags = lodash.without(lodash.union(vm.tags, item.tags_to_add), item.tags_to_remove);
      }
    }

    function questionNavigation(direction) {
      vm.questionPointer = vm.questionPointer + direction;
      vm.question = vm.questions[vm.questionPointer];
    }
  }
})();
