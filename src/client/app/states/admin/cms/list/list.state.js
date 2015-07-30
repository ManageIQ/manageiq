(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper, navigationHelper) {
    routerHelper.configureStates(getStates());
    navigationHelper.navItems(navItems());
    navigationHelper.sidebarItems(sidebarItems());
  }

  function getStates() {
    return {
      'admin.cms.list': {
        url: '', // No url, this state is the index of admin.cms
        templateUrl: 'app/states/admin/cms/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin CMS List',
        resolve: {
          pages: resolvePages
        }
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {};
  }

  /** @ngInject */
  function resolvePages(ContentPage) {
    return ContentPage.query().$promise;
  }

  /** @ngInject */
  function StateController($rootScope, lodash, logger, $q, $state, pages, Toasts) {
    var vm = this;

    // ATTRIBUTES
    vm.title = 'Admin CMS List';
    vm.pages = pages;

    // METHODS
    vm.deleteContentPage = deleteContentPage;
    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Admin CMS List View');
    }

    function deleteContentPage(page) {
      page.$delete(deleteSuccess, deleteFailure);

      function deleteSuccess() {
        lodash.remove(vm.pages, {id: page.id});
        $rootScope.$emit('pageRemoved', {});
        Toasts.toast('Content deleted.');
      }

      function deleteFailure() {
        Toasts.error('Server returned an error while deleting.');
      }
    }
  }
})();
