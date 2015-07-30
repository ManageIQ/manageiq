(function() {
  'use strict';

  angular.module('app.components')
    .directive('projectDescription', ProjectDescriptionDirective);

  /** @ngInject */
  function ProjectDescriptionDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        project: '=',
        linkTo: '@?'
      },
      link: link,
      templateUrl: 'app/components/project-description/project-description.html',
      controller: ProjectDescriptionController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProjectDescriptionController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
