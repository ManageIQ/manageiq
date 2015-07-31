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
      'marketplace': {
        url: '/marketplace?tags',
        templateUrl: 'app/states/marketplace/marketplace.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Marketplace',
        reloadOnSearch: false
      }
    };
  }

  function navItems() {
    return {
      'cart': {
        type: 'cart'
      }
    };
  }

  function sidebarItems() {
    return {
      'marketplace': {
        type: 'state',
        state: 'marketplace',
        label: 'Marketplace',
        style: 'marketplace',
        order: 4
      }
    };
  }

  /** @ngInject */
  function StateController(logger, $q, VIEW_MODES, CatalogService, Tag,
                           Compare, TAG_QUERY_LIMIT, $stateParams, WizardService) {
    var vm = this;

    vm.title = 'Marketplace';
    vm.tags = [];
    vm.viewMode = VIEW_MODES.list;

    vm.activate = activate;
    vm.updateCatalog = updateCatalog;
    vm.queryTags = queryTags;
    vm.openWizard = openWizard;

    activate();

    function activate() {
      updateCatalog();
      Compare.clear();

      if ($stateParams.tags) {
        vm.tags = $stateParams.tags;
      }
      logger.info('Activated Marketplace View');
    }

    function updateCatalog() {
      $q.when(CatalogService.getCatalog(vm.tags)).then(handleResults);

      function handleResults(results) {
        vm.catalog = results;
      }
    }

    function queryTags(query) {
      return Tag.query({q: query, limit: TAG_QUERY_LIMIT}).$promise;
    }

    function openWizard() {
      WizardService.showModal().then(updateTags);

      function updateTags(tags) {
        vm.tags.length = 0;
        Array.prototype.push.apply(vm.tags, tags);
        updateCatalog();
      }
    }
  }
})();
