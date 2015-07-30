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
      'admin.roles.list': {
        url: '', // No url, this state is the index of admin.products
        templateUrl: 'app/states/admin/roles/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Roles List',
        resolve: {
          roles: resolveRoles
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
  function resolveRoles(Role) {
    return Role.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, $state, roles, Toasts, lodash) {
    var vm = this;

    vm.title = 'Admin Roles List';
    vm.roles = roles;
    vm.activate = activate;
    vm.deleteRole = deleteRole;
    vm.permissionsList = permissionsList;
    activate();

    function activate() {
      logger.info('Activated Admin Role List View');
    }

    function deleteRole(index) {
      var roles = vm.roles[index];
      roles.$delete(deleteSuccess, deleteFailure);

      function deleteSuccess() {
        vm.roles.splice(index, 1);
        Toasts.toast('Role deleted.');
      }

      function deleteFailure() {
        Toasts.error('Server returned an error while deleting.');
      }
    }

    function permissionsList(list) {
      return lodash.flatten(lodash.map(list, formatPermissions)).join('');

      function formatPermissions(value, key) {
        return ['<strong>', key, '</strong>: ', value.join(' '), '<br>'];
      }
    }
  }
})();
