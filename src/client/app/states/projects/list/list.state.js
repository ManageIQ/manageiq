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
      'projects.list': {
        url: '', // No url, this state is the index of projects
        templateUrl: 'app/states/projects/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Projects',
        resolve: {
          projects: resolveProjects
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
  function resolveProjects(Project) {
    return Project.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, projects) {
    var vm = this;

    vm.projects = projects;
    vm.activate = activate;
    vm.title = 'Projects';

    activate();

    function activate() {
      logger.info('Activated Project View');
    }
  }
})();
