ManageIQ.angular.app.service('serviceDataFactory', ['API', function(API) {
  var urlBase = '/api/services';

  this.getServiceData = function (id) {
    if(angular.isDefined(id)) {
      return API.get(urlBase + '/' + id).then(handleSuccess);

      function handleSuccess(response) {
        return response;
      }
    }
  };
  return this;
}]);

