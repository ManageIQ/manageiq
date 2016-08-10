ManageIQ.angular.app.service('arbitrationProfileDataFactory', ['API', function(API) {
  var urlBase = '/api/arbitration_profiles';

  this.getArbitrationProfileData = function (ap_id) {
    if(angular.isDefined(ap_id)) {
      return API.get(urlBase + '/' + miqUncompressedId(ap_id))
    }
  };
}]);

