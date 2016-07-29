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

  this.getArbitrationProfileOptions = function (ems_id) {
    var url = "/api/providers/" + ems_id + "?attributes=authentications,availability_zones,cloud_networks,cloud_subnets,flavors,security_groups";
    if(angular.isDefined(ems_id)) {
      return API.get(url).then(handleSuccess);

      function handleSuccess(response) {
        return response;
      }
    }
  };
  return this;
}]);

