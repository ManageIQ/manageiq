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
      'projects.details': {
        url: '/:projectId',
        templateUrl: 'app/states/projects/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Project Details',
        resolve: {
          project: resolveProjects,
          products: resolveProducts,
          staff: resolveStaff,
          groups: resolveGroups,
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
  function resolveProjects($stateParams, Project) {
    return Project.get({
      id: $stateParams.projectId,
      'includes[]': ['latest_alerts', 'approvals', 'approvers', 'services', 'memberships', 'groups', 'project_answers']
    }).$promise;
  }

  /** @ngInject */
  function resolveStaff(Staff) {
    return Staff.getCurrentMember(
      {'includes[]': ['groups']}
    ).$promise;
  }

  /** @ngInject */
  function resolveProducts(Product) {
    return Product.query().$promise;
  }

  /** @ngInject */
  function resolveGroups(Group) {
    return Group.query().$promise;
  }

  /** @ngInject */
  function resolveRoles(Role) {
    return Role.query().$promise;
  }

  /** @ngInject */
  function StateController($state, lodash, project, products, MembershipModal, groups, roles, Membership) {
    var vm = this;

    vm.title = 'Project Details';
    vm.project = project;
    vm.products = products;
    vm.groups = groups;
    vm.roles = roles;

    vm.activate = activate;
    vm.showMembershipModal = showMembershipModal;
    vm.approve = approve;
    vm.reject = reject;

    activate();

    function activate() {
      // Temporary! Merge products onto services
      tempMergeProductsOntoServices();
      vm.project.group_ids = lodash.pluck(vm.project.groups, 'id');
    }

    function approve() {
      $state.reload();
    }

    function reject() {
      $state.transitionTo('projects.list');
    }

    // Private

    function tempMergeProductsOntoServices() {
      angular.forEach(vm.project.services, mergeOnProduct);

      function mergeOnProduct(service) {
        service.product = lodash.find(products, findProduct);

        function findProduct(product) {
          return product.id === service.product_id;
        }
      }
    }

    function showMembershipModal() {
      MembershipModal.showModal(Membership.new({project_id: project.id})).then(updateMembership);

      function updateMembership(result) {
        vm.project.memberships.push(result);
      }
    }
  }
})
();
