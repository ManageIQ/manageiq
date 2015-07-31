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
      'admin.groups.edit': {
        url: '/edit/:groupId',
        templateUrl: 'app/states/admin/groups/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Edit Group',
        resolve: {
          group: resolveGroup,
          staff: resolveStaff
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
  function resolveGroup(Group, $stateParams) {
    return Group.get({id: $stateParams.groupId, 'includes[]': ['staff']}).$promise;
  }

  /** @ngInject */
  function resolveStaff(Staff) {
    return Staff.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, group, staff) {
    var vm = this;

    vm.title = 'Edit Group';
    vm.group = group;
    vm.staff = staff;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Edit Group View');
    }
  }
})();
