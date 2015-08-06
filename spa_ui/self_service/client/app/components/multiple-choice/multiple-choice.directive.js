(function() {
  'use strict';

  angular.module('app.components')
    .directive('multipleChoice', MultipleChoiceDirective);

  function MultipleChoiceDirective() {
    return {
      controller: MultipleChoiceDirectiveController,
      controllerAs: 'vm',
      link: link,
      restrict: 'E',
      scope: {
        action: '&?',
        actionText: '=',
        model: '=',
        options: '='
      },
      templateUrl: 'app/components/multiple-choice/multiple-choice.html'
    };
  }

  function MultipleChoiceDirectiveController(WIZARD_AUTOSUBMIT, WIZARD_MULTIPAGE) {
    var vm = this;

    activate();

    function activate() {
      vm.autoSubmit = WIZARD_AUTOSUBMIT;
      vm.multiPage = WIZARD_MULTIPAGE;
    }
  }

  function link(scope) {
    if (scope.vm.autoSubmit && scope.vm.multiPage) {
      scope.$watch('model', function(newValue) {
        if (newValue) {
          scope.action();
        }
      });
    }
  }
}());
