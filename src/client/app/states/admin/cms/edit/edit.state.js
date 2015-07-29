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
      'admin.cms.edit': {
        url: '/edit/:id',
        templateUrl: 'app/states/admin/cms/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin CMS Edit',
        resolve: {
          contentPageRecord: resolveContentPage
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
  function resolveContentPage($stateParams, ContentPage) {
    if ($stateParams.id) {
      return ContentPage.get({id: $stateParams.id}).$promise;
    } else {
      return {};
    }
  }

  /** @ngInject */
  function StateController(logger, contentPageRecord, $stateParams) {
    var vm = this;

    vm.title = 'Admin CMS Edit';
    vm.contentPageRecord = contentPageRecord;
    vm.activate = activate;
    vm.home = 'admin.cms.list';
    vm.homeParams = { };

    activate();

    function activate() {
      logger.info('Activated Admin CMS Edit View');
    }
  }
})();
