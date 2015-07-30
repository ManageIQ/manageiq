(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectQuestionOption', ProjectQuestionOptionDirective);

  /** @ngInject */
  function ProjectQuestionOptionDirective() {
    var directive = {
      restrict: 'AE',
      require: ['^projectQuestionForm', '^projectQuestionOptions'],
      scope: {
        option: '=',
        index: '=optionIndex',
        label: '@optionLabel'
      },
      link: link,
      templateUrl: 'app/components/project-question-form/project-question-option.html',
      controller: ProjectQuestionOptionController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, ctrls, transclude) {
      var vm = scope.vm;

      vm.activate({
        hasErrors: ctrls[0].hasErrors,
        canRemove: ctrls[1].canRemove,
        removeOption: ctrls[1].removeOption
      });
    }

    /** @ngInject */
    function ProjectQuestionOptionController(Tag, TAG_QUERY_LIMIT) {
      var vm = this;

      vm.activate = activate;
      vm.queryTags = queryTags;
      vm.hasError = hasError;
      vm.remove = remove;

      function activate(api) {
        angular.extend(vm, api);
        vm.option.position = vm.index;
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
