ManageIQ.angular.app.service('arbitrationProfileDataFactory', ['API', function(API) {
  var urlBase = '/api/arbitration_profiles';

  this.getArbitrationProfileData = function (ems_id, ap_id) {
    if(angular.isDefined(ap_id)) {
      id = miqUncompressedId(ap_id)
      return API.get(urlBase + '/' + id).then(handleSuccess);

      function handleSuccess(response) {
        return response;
      }
    }
  };
  return this;
}]);

