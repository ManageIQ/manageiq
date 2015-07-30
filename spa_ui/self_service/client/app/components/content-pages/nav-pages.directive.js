(function() {
  'use strict';

  angular.module('app.components')
    .directive('navPages', NavPagesDirective);

  /** @ngInject */
  function NavPagesDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        item: '='
      },
      link: link,
      templateUrl: 'app/components/content-pages/nav-pages.html',
      controller: NavPagesController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function NavPagesController($rootScope, $scope, $state, $q, ContentPage, lodash) {
      var vm = this;

      // METHODS
      vm.isActive = isActive;
      vm.activate = activate;

      $rootScope.$on('newPageAdded', updatePageList);

      $rootScope.$on('pageRemoved', updatePageList);

      function activate() {
        updatePageList();
      }

      function isActive() {
        return $state.includes(vm.item.state);
      }

      function updatePageList() {
        $q.when(ContentPage.query()).then(handleResults);

        function handleResults(pages) {
          vm.pages = pages;
        }
      }
    }
  }
})();
