ManageIQ.angular.app.controller('arbitrationProfileFormController', ['$scope', '$location', 'arbitrationProfileFormId', 'miqService', 'postService', 'API', 'arbitrationProfileDataFactory', function($scope, $location, arbitrationProfileFormId, miqService, postService, API, arbitrationProfileDataFactory) {
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
      $scope.profileOptions($scope.arbitrationProfileModel.ems_id, $scope.arbitrationProfileModel.cloud_network_id);
      $scope.modelCopy = angular.copy( $scope.arbitrationProfileModel );
    } else {
      var profileId = queryParam('show').toString();
      arbitrationProfileDataFactory.getArbitrationProfileData(profileId).then (function(arbitrationProfileData) {
        $scope.newRecord = false;
        $scope.arbitrationProfileModel.name                 = arbitrationProfileData.name;
        $scope.arbitrationProfileModel.description          = arbitrationProfileData.description;
        $scope.arbitrationProfileModel.authentication_id    = arbitrationProfileData.authentication_id;
        $scope.arbitrationProfileModel.availability_zone_id = arbitrationProfileData.availability_zone_id;
        $scope.arbitrationProfileModel.cloud_network_id     = arbitrationProfileData.cloud_network_id;
        $scope.arbitrationProfileModel.cloud_subnet_id      = arbitrationProfileData.cloud_subnet_id;
        $scope.arbitrationProfileModel.flavor_id            = arbitrationProfileData.flavor_id;
        $scope.arbitrationProfileModel.security_group_id    = arbitrationProfileData.security_group_id;

        $scope.profileOptions($scope.arbitrationProfileModel.ems_id, $scope.arbitrationProfileModel.cloud_network_id);
        $scope.modelCopy = angular.copy( $scope.arbitrationProfileModel );
      });
    }
  };

  $scope.cancelClicked = function() {
    if ($scope.newRecord)
      var msg = sprintf(__("Add of Arbitration Profile was cancelled by the user"));
    else
      var msg = sprintf(__("Edit of Arbitration Profile %s was cancelled by the user"), $scope.arbitrationProfileModel.description);
    postService.cancelOperation(redirectUrl, msg);
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.arbitrationProfileModel = angular.copy( $scope.modelCopy );
    $scope.profileOptions($scope.arbitrationProfileModel.ems_id, $scope.arbitrationProfileModel.cloud_network_id);
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

  $scope.cloudNetworkChanged = function(id) {
    var url = "/api/cloud_networks/" + id + "?attributes=cloud_subnets,security_groups";

    API.get(url).then(function(response) {
      $scope.cloud_subnets   = response.cloud_subnets;
      $scope.security_groups = response.security_groups;
      $scope._cloud_subnet = _.find($scope.cloud_subnets, {id: $scope.arbitrationProfileModel.cloud_subnet_id})
      $scope._security_group = _.find($scope.security_groups, {id: $scope.arbitrationProfileModel.security_group_id})
    })

    if ($scope.arbitrationProfileModel.cloud_network_id != id){
      $scope.arbitrationProfileModel.cloud_subnet_id = '';
      $scope.arbitrationProfileModel.security_group_id = '';
    }
    $scope.arbitrationProfileModel.cloud_network_id = id;
  };

  $scope.profileOptions = function(id, cloud_network_id) {
    var url = "/api/providers/" + id + "?attributes=key_pairs,availability_zones,cloud_networks,cloud_subnets,flavors,security_groups";

    API.get(url).then(function(response) {
      $scope.authentications    = response.key_pairs;
      $scope.availability_zones = response.availability_zones;
      $scope.flavors            = response.flavors;
      $scope.cloud_networks     = response.cloud_networks;
      if(cloud_network_id != "") {
        $scope.cloudNetworkChanged(cloud_network_id)
      } else {
        $scope.cloud_subnets   = response.cloud_subnets;
        $scope.security_groups = response.security_groups;
      }
      $scope._authentication = _.find($scope.authentications, {id: $scope.arbitrationProfileModel.authentication_id})
      $scope._availability_zone = _.find($scope.availability_zones, {id: $scope.arbitrationProfileModel.availability_zone_id})
      $scope._flavor = _.find($scope.flavors, {id: $scope.arbitrationProfileModel.flavor_id})
      $scope._cloud_network = _.find($scope.cloud_networks, {id: $scope.arbitrationProfileModel.cloud_network_id})
      $scope._cloud_subnet = _.find($scope.cloud_subnets, {id: $scope.arbitrationProfileModel.cloud_subnet_id})
      $scope._security_group = _.find($scope.security_groups, {id: $scope.arbitrationProfileModel.security_group_id})
    })

  };

  $scope.$watch('_cloud_network', function(value) {
    if (value) {
      $scope.cloudNetworkChanged(value.id)
      $scope.arbitrationProfileModel[name + '_id'] = value.id;
    }
  });

  // watch for all the drop downs on screen
  "authentication availability_zone flavor cloud_subnet security_group".split(" ").forEach(idWatch)

  function idWatch(name) {
    $scope.$watch('_' + name, function(value) {
      if (value) {
        $scope.arbitrationProfileModel[name + '_id'] = value.id;
      }
    });
  }

  init();
}]);
