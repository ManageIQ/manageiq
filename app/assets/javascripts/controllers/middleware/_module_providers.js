miqHttpInject(angular.module('middleware.provider', ['miQStaticAssets', 'ui.bootstrap', 'ui.router', 'patternfly.select', 'ui.bootstrap.tabs', 'patternfly.views', 'ngAnimate']))
.config(function(MiQDataAccessServiceProvider, MiQFormValidatorServiceProvider, MiQDataTableServiceProvider) {

  var prefixLocation = location.pathname.split('/')[1];
  MiQDataAccessServiceProvider.setUrlPrefix('/' + prefixLocation);
  MiQDataTableServiceProvider.endpoints = {
    list: '/list_providers',
    deleteItems: '/delete_provider'
  };
  MiQFormValidatorServiceProvider.endpoints = {
    validate: '/validate_provider',
    create: '/new_provider'
  }
})
.config(function($stateProvider, $locationProvider, $urlRouterProvider, MiQDataAccessServiceProvider, MiQNewProviderStateServiceProvider) {
  MiQNewProviderStateServiceProvider.$stateProvider = $stateProvider;
  $stateProvider.state('list_providers', {
    url: MiQDataAccessServiceProvider.urlPrefix + '/show_list',
    views: {
      'toolbar': {
        templateUrl: '/static/providers/toolbar.html'
      },
      'content': {
        templateUrl: '/static/providers/list_providers.html'
      }
    }
  })
  .state('list_providers.list', {
    url: '/list',
    templateUrl: '/static/providers/list_providers/list_view.html',
    hasTree: true
  })
  .state('list_providers.tile', {
    url: '/tile',
    templateUrl: '/static/providers/list_providers/tile_view.html',
    hasTree: true
  })
  .state('list_providers.grid', {
    url: '/grid',
    templateUrl: '/static/providers/list_providers/grid_view.html',
    hasTree: true
  })
  .state('new_provider', {
    url: MiQDataAccessServiceProvider.urlPrefix + '/new',
    views: {
      'content': {
        templateUrl: '/static/providers/new_provider/new.html',
        controller: 'miqNewProviderController as mwNew'
      }
    }
  });

  $locationProvider.html5Mode({
    enabled: true,
    requireBase: false
  });
  $urlRouterProvider.otherwise(MiQDataAccessServiceProvider.urlPrefix + '/show_list/list');
  $urlRouterProvider.otherwise(function ($injector, $location) {
    if ($location.hash().length != 0) {
      var rootUrl = $location.path().substring(0, $location.path().lastIndexOf('/'));
      return rootUrl +
        ($location.hash().indexOf('/') !== 0 ? '/' + $location.hash() : $location.hash());
    } else {
      return MiQDataAccessServiceProvider.urlPrefix + '/show_list/list';
    }
  });
});
