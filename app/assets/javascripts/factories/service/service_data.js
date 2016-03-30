ManageIQ.angular.app.factory('serviceDataFactory', ['API', function(API) {
  var factoryService = {
    getServiceData: function(id) {
      if(angular.isDefined(id)) {
        return API.get('/api/services/' + id)
      }
    }
  };
  return factoryService;
}]);
