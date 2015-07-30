(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectAnswersTable', ProjectAnswersTableDirective);

  /** @ngInject */
  function ProjectAnswersTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        answers: '='
      },
      link: link,
      templateUrl: 'app/components/project-answers-table/project-answers-table.html',
      controller: ProjectAnswersTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectAnswersTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
