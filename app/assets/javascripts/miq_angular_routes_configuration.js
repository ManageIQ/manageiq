ManageIQ.angular.app.config([ '$httpProvider', '$stateProvider', '$urlRouterProvider', '$locationProvider', function ($httpProvider, $stateProvider, $urlRouterProvider, $locationProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');

  /**
   * Routes and States for Repository
   */
  $stateProvider
    .state('new', {
      url: '/repository/new',
      templateUrl: 'repository/form.html',
      controller: 'repositoryFormController',
      resolve: {
        repositoryData: function (repositoryDataFactory) {
          return repositoryDataFactory.getRepositoryData();
        }
      }
    });
  $stateProvider
    .state('edit', {
      url: '/repository/edit/:repo_id',
      templateUrl: 'repository/form.html',
      controller: 'repositoryFormController',
      resolve: {
        repositoryData: function (repositoryDataFactory, $stateParams) {
          return repositoryDataFactory.getRepositoryData($stateParams.repo_id);
        }
      }
    });
  $stateProvider
    .state("otherwise", {
      url: "*path"
    });

  // default fall back route
  //$urlRouterProvider.otherwise('/');

  // enable HTML5 Mode for SEO
  $locationProvider.html5Mode({enabled: true,requireBase: false});
}]);

ManageIQ.angular.app.run(['$rootScope', 'miqService', '$window', function($rootScope, miqService, $window) {
  var otherwisePath;
  $rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
    if (toState.name === "otherwise") {
      event.preventDefault();
      otherwisePath = toParams.path;
    }
    else {
      miqService.sparkleOn();
    }
  });

  $rootScope.$on('$stateChangeSuccess', function(event, toState, toParams, fromState, fromParams) {
    miqService.sparkleOff();
  });

  $rootScope.$on('$locationChangeSuccess', function(event, newURL, oldURL, newState, oldState) {
    if (angular.isDefined(otherwisePath) && $window.location.pathname != otherwisePath ) {
      miqService.sparkleOn();
      $window.location.href = otherwisePath;
    }
  });

}]);
