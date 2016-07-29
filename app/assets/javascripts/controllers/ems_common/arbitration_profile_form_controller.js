ManageIQ.angular.app.controller('arbitrationProfileFormController', ['$http', '$scope', '$location', 'arbitrationProfileFormId', 'miqService', 'postService', 'arbitrationProfileData', 'arbitrationProfileOptions', function($http, $scope, $location, arbitrationProfileFormId, miqService, postService, arbitrationProfileData, arbitrationProfileOptions) {
    var init = function() {
      $scope.arbitrationProfileModel = {
        name: '',
        description: '',
        ems_id: emsId,
        authentication_id: '',
        availability_zone_id: '',
        cloud_network_id: '',
        cloud_subnet_id: '',
        flavor_id: '',
        security_group_id: ''
      };
      $scope.formId    = arbitrationProfileFormId;
      $scope.afterGet  = false;
      $scope.model     = "arbitrationProfileModel";
      ManageIQ.angular.scope = $scope;

      if (arbitrationProfileFormId == 'new') {
        $scope.newRecord = true;
        $scope.arbitrationProfileModel.ems_id = emsId;
      } else {
        $scope.newRecord = false;
        $scope.arbitrationProfileModel.name                 = arbitrationProfileData.name;
        $scope.arbitrationProfileModel.description          = arbitrationProfileData.description;
        $scope.arbitrationProfileModel.authentication_id    = convertToString(arbitrationProfileData.authentication_id);
        $scope.arbitrationProfileModel.availability_zone_id = convertToString(arbitrationProfileData.availability_zone_id);
        $scope.arbitrationProfileModel.cloud_network_id     = convertToString(arbitrationProfileData.cloud_network_id);
        $scope.arbitrationProfileModel.cloud_subnet_id      = convertToString(arbitrationProfileData.cloud_subnet_id);
        $scope.arbitrationProfileModel.flavor_id            = convertToString(arbitrationProfileData.flavor_id);
        $scope.arbitrationProfileModel.security_group_id    = convertToString(arbitrationProfileData.security_group_id);
      }

      $scope.arbitrationProfileModel.authentications    = arbitrationProfileOptions.authentications
      $scope.arbitrationProfileModel.availability_zones = arbitrationProfileOptions.availability_zones
      $scope.arbitrationProfileModel.cloud_networks     = arbitrationProfileOptions.cloud_networks
      $scope.arbitrationProfileModel.cloud_subnets      = arbitrationProfileOptions.cloud_subnets
      $scope.arbitrationProfileModel.flavors            = arbitrationProfileOptions.flavors
      $scope.arbitrationProfileModel.security_groups    = arbitrationProfileOptions.security_groups

      $scope.modelCopy = angular.copy( $scope.arbitrationProfileModel );
    };

  $scope.cancelClicked = function() {
    var task = $scope.newRecord ? "Add" : "Edit"
    var msg = sprintf(__(task + " of Arbitration Profile %s was cancelled by the user"), $scope.arbitrationProfileModel.description);
    postService.cancelOperation(redirectUrl, msg);
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.arbitrationProfileModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function() {
    var successMsg = sprintf(__("Arbitration Profile %s was saved"), $scope.arbitrationProfileModel.name);
    postService.saveRecord('/api/arbitration_profiles/' + arbitrationProfileFormId,
      redirectUrl,
      setProfileOptions(),
      successMsg);
    $scope.angularForm.$setPristine(true);
  };

  $scope.addClicked = function($event, formSubmit) {
    var successMsg = sprintf(__("Arbitration Profile %s was added"), $scope.arbitrationProfileModel.name);
    postService.createRecord('/api/arbitration_profiles',
      redirectUrl,
      setProfileOptions(),
      successMsg);
    $scope.angularForm.$setPristine(true);
  };

  // extract ems_id from url
  var emsId = (/ems_cloud\/arbitration_profile_edit\/(\d+)/.exec($location.absUrl())[1]);
  var redirectUrl = '/ems_cloud/arbitration_profiles/' + emsId + '?db=ems_cloud';

  var convertToString = function(id) {
    if(angular.isDefined(id)) {
      return id.toString();
    }
    return '';
  }

  var setProfileOptions = function() {
    return {
              name:                 $scope.arbitrationProfileModel.name,
              description:          $scope.arbitrationProfileModel.description,
              ems_id:               $scope.arbitrationProfileModel.ems_id,
              authentication_id:    $scope.arbitrationProfileModel.authentication_id,
              availability_zone_id: $scope.arbitrationProfileModel.availability_zone_id,
              cloud_network_id:     $scope.arbitrationProfileModel.cloud_network_id,
              cloud_subnet_id:      $scope.arbitrationProfileModel.cloud_subnet_id,
              flavor_id:            $scope.arbitrationProfileModel.flavor_id,
              security_group_id:    $scope.arbitrationProfileModel.security_group_id
            }
  }
  init();
}]);
