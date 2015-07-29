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
      'admin.cms.create': {
        url: '/create',
        templateUrl: 'app/states/admin/cms/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin CMS Create',
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
    return new ContentPage();
  }

  /** @ngInject */
  function StateController(logger, contentPageRecord, $stateParams) {
    var vm = this;

    vm.title = 'Admin CMS Create';
    vm.contentPageRecord = contentPageRecord;
    vm.activate = activate;
    vm.home = 'admin.cms.list';
    vm.homeParams = { };

    activate();

    function activate() {
      logger.info('Activated Admin CMS Create View');
    }
  }
})();
