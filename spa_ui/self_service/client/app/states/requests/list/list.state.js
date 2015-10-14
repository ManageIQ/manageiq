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
      'requests.list': {
        url: '',
        templateUrl: 'app/states/requests/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Request List',
        resolve: {
          requests: resolveRequests
        }
      }
    };
  }

  /** @ngInject */
  function resolveRequests(CollectionsApi) {
    var options = {expand: 'resources', attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.query('service_requests', options);
  }

  /** @ngInject */
  function StateController($state, requests) {
    var vm = this;

    vm.title = 'Request List';
    vm.requests = requests.resources;
    vm.requestsList = angular.copy(vm.requests);

    vm.listConfig = {
      selectItems: false,
      showSelectBox: false,
      selectionMatchProp: 'request_status',
      onClick: handleClick
    };

    var listState = {
      sort: {
        isAscending: false,
        currentField: { id: 'requested', title: 'Requested Date', sortType: 'numeric' }
      }
    };

    vm.toolbarConfig = {
      filterConfig: {
        fields: [
           {
            id: 'description',
            title:  'Description',
            placeholder: 'Filter by Description',
            sortType: 'alpha'
          },
          {
            id: 'request_id',
            title: 'Request Id',
            placeholder: 'Filter by ID',
            filterType: 'text'
          },
          {
            id: 'request_state',
            title: 'Request Status',
            placeholder: 'Filter by Status',
            filterType: 'select',
            filterValues: ['Pending', 'Denied', 'Finished']
          }
        ],
        resultsCount: vm.requestsList.length,
        appliedFilters: [],
        onFilterChange: filterChange
      },
      sortConfig: {
        fields: [
          {
            id: 'description',
            title: 'Description',
            sortType: 'alpha'
          },
          {
            id: 'id',
            title: 'ID',
            sortType: 'numeric'
          },
          {
            id: 'requested',
            title: 'Requested Date',
            sortType: 'numeric'
          },
          {
            id: 'status',
            title: 'Status',
            sortType: 'alpha'
          }
        ],
        onSortChange: sortChange,
        isAscending: listState.sort.isAscending,
        currentField: listState.sort.currentField
      }
    };

    /* Set the list sort state */
    sortChange(listState.sort.currentField, listState.sort.isAscending);

    function handleClick(item, e) {
      $state.go('requests.details', {requestId: item.id});
    }

    function sortChange(sortId, isAscending) {
      vm.requestsList.sort(compareFn);

      /* Keep track of the current sorting state */
      listState.sort.isAscending = isAscending;
      listState.sort.currentField = sortId;
    }

    function compareFn(item1, item2) {
      var compValue = 0;
      if (vm.toolbarConfig.sortConfig.currentField.id === 'description') {
        compValue = item1.description.localeCompare(item2.description);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'id') {
        compValue = item1.id - item2.id;
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'requested') {
        compValue = new Date(item1.created_on) - new Date(item2.created_on);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'status') {
        compValue = item1.request_state.localeCompare(item2.request_state);
      }

      if (!vm.toolbarConfig.sortConfig.isAscending) {
        compValue = compValue * -1;
      }

      return compValue;
    }

    function filterChange(filters) {
      vm.filtersText = '';
      angular.forEach(filters, filterTextFactory);

      function filterTextFactory(filter) {
        vm.filtersText += filter.title + ' : ' + filter.value + '\n';
      }

      applyFilters(filters);
      vm.toolbarConfig.filterConfig.resultsCount = vm.requestsList.length;

      /* Make sure sorting direction is maintained */
      sortChange(listState.sort.currentField, listState.sort.isAscending);
    }

    function applyFilters(filters) {
      vm.requestsList = [];
      if (filters && filters.length > 0) {
        angular.forEach(vm.requests, filterChecker);
      } else {
        vm.requestsList = vm.requests;
      }

      function filterChecker(item) {
        if (matchesFilters(item, filters)) {
          vm.requestsList.push(item);
        }
      }
    }

    function matchesFilters(item, filters) {
      var matches = true;
      angular.forEach(filters, filterMatcher);

      function filterMatcher(filter) {
        if (!matchesFilter(item, filter)) {
          matches = false;

          return false;
        }
      }

      return matches;
    }

    function matchesFilter(item, filter) {
      if ('description' === filter.id) {
        return item.description.toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      } else if (filter.id === 'request_state') {
        return item.request_state.toLowerCase() === filter.value.toLowerCase();
      } else if (filter.id === 'request_id') {
        return String(item.id).toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      } 

      return false;
    }
  }
})();
