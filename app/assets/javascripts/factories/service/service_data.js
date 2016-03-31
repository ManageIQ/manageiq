ManageIQ.angular.app.factory('serviceDataFactory', ['API', function(API) {
  var urlBase = '/api/services';
  var serviceDataFactory = {};

  serviceDataFactory.getServiceData = function (id) {
    if(angular.isDefined(id)) {
      return API.get(urlBase + '/' + id).then(handleSuccess);

      function handleSuccess(response) {
        return response;
      }
    }
  };
  return serviceDataFactory;
}]);
