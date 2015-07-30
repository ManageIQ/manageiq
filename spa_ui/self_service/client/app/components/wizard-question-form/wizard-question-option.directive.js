(function() {
  'use strict';

  angular.module('app.components')
    .directive('wizardQuestionOption', WizardQuestionOptionDirective);

  /** @ngInject */
  function WizardQuestionOptionDirective() {
    var directive = {
      restrict: 'AE',
      require: ['^wizardQuestionForm', '^wizardQuestionOptions'],
      scope: {
        option: '=',
        index: '=optionIndex',
        label: '@optionLabel'
      },
      link: link,
      templateUrl: 'app/components/wizard-question-form/wizard-question-option.html',
      controller: WizardQuestionOptionController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, ctrls, transclude) {
      var vm = scope.vm;

      vm.activate({
        hasErrors: ctrls[0].hasErrors,
        canRemove: ctrls[1].canRemove,
        canSort: ctrls[1].canSort,
        removeOption: ctrls[1].removeOption
      });
    }

    /** @ngInject */
    function WizardQuestionOptionController(Tag, TAG_QUERY_LIMIT) {
      var vm = this;

      vm.activate = activate;
      vm.queryTags = queryTags;
      vm.hasError = hasError;
      vm.remove = remove;

      function activate(api) {
        angular.extend(vm, api);
      }

      function queryTags(query) {
        return Tag.query({q: query, limit: TAG_QUERY_LIMIT}).$promise;
      }

      function hasError() {
        return vm.hasErrors() && vm.form.option.$invalid;
      }

      function remove() {
        vm.removeOption(vm.index);
      }
    }
  }
})();
