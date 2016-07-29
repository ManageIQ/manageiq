ManageIQ.angular.app.factory('serviceDataFactory', ['$http', function($http) {
  var factoryService = {
    getServiceData: function(id) {
      if(angular.isDefined(id)) {
        var promise = $http({
          method: 'GET',
          url: '/service/service_form_fields/' + id
        }).success(function (data, status, headers, config) {
          return data;
        });
        return promise;
      }
    }
  }
  return factoryService;
}]);

