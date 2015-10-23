(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'dashboard': {
        parent: 'application',
        url: '/',
        templateUrl: 'app/states/dashboard/dashboard.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Dashboard',
        data: {
          requireUser: true
        },
        resolve: {
          retiredServices: resolveRetiredServices,
          expiringServices: resolveExpiringServices,
          pendingRequests: resolvePendingRequests,
          approvedRequests: resolveApprovedRequests,
          deniedRequests: resolveDeniedRequests
        }
      }
    };
  }

  /** @ngInject */
  function resolvePendingRequests(CollectionsApi) {
    var options = {expand: false, filter: ['approval_state=pending'] };

    return CollectionsApi.query('service_requests', options);
  }

  /** @ngInject */
  function resolveApprovedRequests(CollectionsApi) {
    var options = {expand: false, filter: ['approval_state=approved'] };

    return CollectionsApi.query('service_requests', options);
  }

  /** @ngInject */
  function resolveDeniedRequests(CollectionsApi) {
    var options = {expand: false, filter: ['approval_state=denied'] };

    return CollectionsApi.query('service_requests', options);
  }

  /** @ngInject */
  function resolveExpiringServices(CollectionsApi, $filter) {
    var currentDate = new Date();
    var date1 = 'retires_on>=' + $filter('date')(currentDate, 'yyyy-MM-dd');

    var days30 = currentDate.setDate(currentDate.getDate() + 30);
    var date2 = 'retires_on<=' + $filter('date')(days30, 'yyyy-MM-dd');
    var options = {expand: false, filter: [date1, date2]};

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function resolveRetiredServices(CollectionsApi) {
    var options = {expand: false, filter: ['retired=true'] };

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function StateController($state, RequestsState, ServicesState, retiredServices, 
    expiringServices, pendingRequests, approvedRequests, deniedRequests) {
    var vm = this;
    vm.servicesCount = {};
    vm.servicesCount.total = retiredServices.count;
    vm.servicesCount.retired = retiredServices.subcount;
    vm.servicesCount.current = retiredServices.count - retiredServices.subcount;
    vm.servicesCount.soon = expiringServices.subcount;

    vm.requestsCount = {};
    vm.requestsCount.total = pendingRequests.count;
    vm.requestsCount.pending = pendingRequests.subcount;
    vm.requestsCount.approved = approvedRequests.subcount;
    vm.requestsCount.denied = deniedRequests.subcount;

    vm.title = 'Dashboard';

    vm.navigateToRequestsList = function(filterValue) {
      RequestsState.setFilters([{'id': 'approval_state', 'title': 'Request Status', 'value': filterValue}]);
      $state.go('requests.list');
    };

    vm.navigateToServicesList = function(filterValue) {
      ServicesState.setFilters([{'id': 'retirement', 'title': 'Retirement Date', 'value': filterValue}]);
      $state.go('services.list');
    };
  }
})();
