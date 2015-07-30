(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectQuestionOptions', ProjectQuestionOptionsDirective);

  /** @ngInject */
  function ProjectQuestionOptionsDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        options: '=',
        type: '=optionsType',
        maxOptions: '=?'
      },
      link: link,
      templateUrl: 'app/components/project-question-form/project-question-options.html',
      controller: ProjectQuestionOptionsController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectQuestionOptionsController(ProjectQuestion) {
      var vm = this;

      var MAX_OPTIONS = 10;

      vm.sortableOptions = {
        axis: 'y',
        cursor: 'move',
        handle: '.project-question-options__handle',
        opacity: 0.9,
        placeholder: 'project-question-options__placeholder'
      };

      vm.activate = activate;
      vm.addOption = addOption;
      vm.optionLabel = optionLabel;
      vm.canAdd = canAdd;
      vm.canRemove = canRemove;
      vm.removeOption = removeOption;

      function activate() {
        vm.maxOptions = angular.isDefined(vm.maxOptions) ? vm.maxOptions : MAX_OPTIONS;
      }

      function addOption() {
        vm.options.push(angular.extend({}, ProjectQuestion.optionDefaults));
      }

      function optionLabel(index) {
        if ('select_option' === vm.type) {
          return 'Option ' + (index + 1);
        }
      }

      function canAdd() {
        return 'select_option' === vm.type && vm.options.length < vm.maxOptions;
      }

      function canRemove() {
        return vm.options.length > 2;
      }

      function removeOption(index) {
        vm.options.splice(index, 1);
      }
    }
  }
})();
