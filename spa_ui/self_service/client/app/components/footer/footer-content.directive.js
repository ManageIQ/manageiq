(function() {
  'use strict';

  angular.module('app.components')
    .directive('footerContent', FooterContentDirective);

  /** @ngInject */
  function FooterContentDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {},
      link: link,
      templateUrl: 'app/components/footer/footer-content.html',
      controller: FooterController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function FooterController(Navigation) {
      var vm = this;

      vm.activate = activate;
      vm.dateTime = new Date();

      function activate() {
      }
    }
  }
})();
