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
      'marketplace.list': {
        url: '',
        templateUrl: 'app/states/marketplace/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Catalog',
        resolve: {
          serviceTemplates: resolveServiceTemplates
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceTemplates(CollectionsApi) {
    var options = {expand: 'resources', filter: ['display=true'], attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.query('service_templates', options);
  }

  /** @ngInject */
  function StateController($state, serviceTemplates) {
    var vm = this;

    vm.title = 'Service Catalog';
    vm.serviceTemplates = serviceTemplates.resources;
    vm.serviceTemplatesList = angular.copy(vm.serviceTemplates);

    vm.showDetails = showDetails;

    function showDetails(template) {
      $state.go('marketplace.details', {serviceTemplateId: template});
    }

    vm.toolbarConfig = {
      filterConfig: {
        fields: [
          {
            id: 'template_name',
            title: 'Service Template Name',
            placeholder: 'Filter by Name',
            filterType: 'text'
          },
          {
            id: 'template_description',
            title: 'Service Template Description',
            placeholder: 'Filter by Template Description',
            filterType: 'text'
          }
        ],
        resultsCount: vm.serviceTemplatesList.length,
        appliedFilters: [],
        onFilterChange: filterChange
      }
    };

    function filterChange(filters) {
      vm.filtersText = '';
      angular.forEach(filters, filterTextFactory);

      function filterTextFactory(filter) {
        vm.filtersText += filter.title + ' : ' + filter.value + '\n';
      }

      applyFilters(filters);
      vm.toolbarConfig.filterConfig.resultsCount = vm.serviceTemplatesList.length;
    }

    function applyFilters(filters) {
      vm.serviceTemplatesList = [];
      if (filters && filters.length > 0) {
        angular.forEach(vm.serviceTemplates, filterChecker);
      } else {
        vm.serviceTemplatesList = vm.serviceTemplates;
      }

      function filterChecker(item) {
        if (matchesFilters(item, filters)) {
          vm.serviceTemplatesList.push(item);
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
      var match = true;
      if (filter.id === 'template_name') {
        match = (String(item.name).toLowerCase().indexOf(String(filter.value).toLowerCase()) > -1 );
      } else if (filter.id === 'template_description') {
        match = (String(item.long_description).toLowerCase().indexOf(String(filter.value).toLowerCase()) > -1 );
      }

      return match;
    }
  }
})();
