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
      'admin.groups.list': {
        url: '', // No url, this state is the index of admin.products
        templateUrl: 'app/states/admin/groups/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Groups List',
        resolve: {
          groups: resolveGroups
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
  function resolveGroups($stateParams, Group) {
    return Group.query({'includes[]': ['staff']}).$promise;
  }

  /** @ngInject */
  function StateController(logger, $q, $state, groups, Toasts) {
    var vm = this;

    vm.title = 'Admin Groups List';
    vm.groups = groups;
    vm.activate = activate;
    vm.goTo = goTo;

    activate();

    function activate() {
      logger.info('Activated Admin Groups List View');
    }

    function goTo(id) {
      $state.go('admin.groups.create', {id: id});
    }

    vm.deleteGroup = deleteGroup;

    function deleteGroup(index) {
      var group = vm.groups[index];
      group.$delete(deleteSuccess, deleteFailure);

      function deleteSuccess() {
        vm.groups.splice(index, 1);
        Toasts.toast('Group deleted.');
      }

      function deleteFailure() {
        Toasts.error('Server returned an error while deleting.');
      }
    }
  }
})();
