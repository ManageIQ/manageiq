(function() {
  'use strict';

  angular.module('app.components')
    .directive('wizardQuestionOptions', WizardQuestionOptionsDirective);

  /** @ngInject */
  function WizardQuestionOptionsDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        options: '=',
        maxOptions: '=?'
      },
      link: link,
      templateUrl: 'app/components/wizard-question-form/wizard-question-options.html',
      controller: WizardQuestionOptionsController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function WizardQuestionOptionsController(WizardQuestion, lodash) {
      var vm = this;

      var MAX_OPTIONS = 10;

      vm.activate = activate;
      vm.canAdd = canAdd;
      vm.addOption = addOption;
      vm.canRemove = canRemove;
      vm.removeOption = removeOption;

      function activate() {
        vm.maxOptions = angular.isDefined(vm.maxOptions) ? vm.maxOptions : MAX_OPTIONS;
      }

      function addOption() {
        vm.options.push(angular.extend({}, WizardQuestion.optionDefaults));
      }

      function removeOption(index) {
        // jscs:disable disallowDanglingUnderscores
        vm.options[index]._destroy = true;
        // jscs:enable
      }

      function canAdd() {
        return MAX_OPTIONS > vm.options.length;
      }

      function canRemove() {
        return lodash.reject(vm.options, {'_destroy': true}).length > 2;
      }
    }
  }
})();
