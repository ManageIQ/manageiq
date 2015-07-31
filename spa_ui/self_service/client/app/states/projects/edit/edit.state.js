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
      'projects.edit': {
        url: '/edit/:projectId',
        templateUrl: 'app/states/projects/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Project Edit Role',
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
  function resolveProject(Project, $stateParams) {
    return Project.get({
      id: $stateParams.projectId,
      'includes[]': ['approvals', 'approvers', 'services', 'memberships', 'groups', 'project_answers']
    }).$promise;
  }

  /** @ngInject */
  function StateController(logger, project) {
    var vm = this;

    vm.title = 'Project Role';
    vm.project = project;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Edit Project View');
    }
  }
})();
