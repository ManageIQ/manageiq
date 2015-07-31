(function() {
  'use strict';

  angular.module('app.components')
    .directive('wizardQuestionsTable', WizardQuestionsTableDirective);

  /** @ngInject */
  function WizardQuestionsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        questions: '='
      },
      link: link,
      templateUrl: 'app/components/wizard-questions-table/wizard-questions-table.html',
      controller: WizardQuestionsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function WizardQuestionsTableController(Toasts, jQuery, $timeout) {
      var vm = this;

      vm.sortableOptions = {
        axis: 'y',
        cursor: 'move',
        handle: '.wizard-questions-table__handle',
        helper: sortableHelper,
        opacity: 0.9,
        placeholder: 'wizard-questions-table__placeholder',
        update: sortableUpdate
      };

      vm.activate = activate;
      vm.deleteQuestion = deleteQuestion;

      function activate() {
      }

      function deleteQuestion(index) {
        var question = vm.questions[index];

        question.$delete(deleteSuccess, deleteFailure);

        function deleteSuccess() {
          vm.questions.splice(index, 1);
          Toasts.toast('Wizard Question deleted.');
        }

        function deleteFailure() {
          Toasts.error('Server returned an error while deleting.');
        }
      }

      // Private

      function sortableHelper(event, element) {
        var $originals = element.children();
        var $helper = element.clone();

        $helper.children().each(setCloneWidth);

        return $helper;

        function setCloneWidth(index, element) {
          // Set helper cell sizes to match the original sizes
          jQuery(element).width($originals.eq(index).width());
        }
      }

      function sortableUpdate(event, ui) {
        var question = angular.element(ui.item).scope().row;

        // Update fires before the mode is updated; Stop won't tell us if we actually moved anything
        // So wait a moment and let things settle then perform the update
        $timeout(savePosition);

        function savePosition() {
          question.load_order = ui.item.index();
          question.$update(updateSuccess, updateFailure);

          function updateSuccess() {
            Toasts.toast('Wizard Question order saved.');
          }

          function updateFailure() {
            Toasts.error('Server returned an error while saving.');
          }
        }
      }
    }
  }
})();
