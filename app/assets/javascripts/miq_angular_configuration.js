ManageIQ.angular.app.config([ '$httpProvider', '$stateProvider', '$urlRouterProvider', '$locationProvider', function ($httpProvider, $stateProvider, $urlRouterProvider, $locationProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');

  /**
   * Routes and States for Repository
   */
  $stateProvider
    .state('edit', {
      url: '/service/:service_id/edit',
      templateUrl: 'service/edit.html',
      controller: 'serviceFormController',
      resolve: {
        serviceData: function (serviceDataFactory, $stateParams) {
          return serviceDataFactory.getServiceData($stateParams.service_id);
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
  var otherwisePath, newUrlPath;
  $rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
    if (toState.name === "otherwise") {
      event.preventDefault();
      otherwisePath = newUrlPath;
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
    } else {
      newUrlPath = newURL;
    }
  });
}]);
