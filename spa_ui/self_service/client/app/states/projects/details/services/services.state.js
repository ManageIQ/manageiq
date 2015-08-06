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
      'projects.services': {
        url: '/:projectId/add-services',
        templateUrl: 'app/states/projects/details/services/services.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Add Services',
        resolve: {
          project: resolveProject
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
  function resolveProject($stateParams, Project) {
    return Project.get({id: $stateParams.projectId}).$promise;
  }

  /** @ngInject */
  function StateController(logger, $q, VIEW_MODES, CatalogService, Tag,
                           Compare, TAG_QUERY_LIMIT, project, WizardService) {
    var vm = this;

    vm.title = 'Marketplace';
    vm.project = project;
    vm.tags = [];
    vm.viewMode = VIEW_MODES.list;

    vm.activate = activate;
    vm.updateCatalog = updateCatalog;
    vm.queryTags = queryTags;
    vm.openWizard = openWizard;

    activate();

    function activate() {
      logger.info('Activated Add Services View');
      updateCatalog();
      Compare.clear();
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
      }
    }
  }
})();
