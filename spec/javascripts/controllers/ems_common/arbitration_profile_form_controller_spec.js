describe('arbitrationProfileFormController', function() {
  var $scope, $location, $controller, $httpBackend, miqService, postService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, $location, _$controller_, _$httpBackend_, _miqService_, _postService_) {
    miqService = _miqService_;
    postService = _postService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    spyOn(postService, 'cancelOperation');
    spyOn(postService, 'saveRecord');
    spyOn(postService, 'createRecord');

    spyOn($location, 'absUrl').and.returnValue('/ems_cloud/arbitration_profile_edit/1000000000001?db=ems_cloud')
    $scope = $rootScope.$new();
    $location = $location;
    $httpBackend = _$httpBackend_;

    var arbitrationProfileData = {name:                 'arbitrationProfileName',
                                  description:          'arbitrationProfileDescription',
                                  ems_id:               '1000000000001',
                                  authentication_id:    '1000000000005',
                                  availability_zone_id: '1000000000006',
                                  cloud_network_id:     '1000000000007',
                                  cloud_subnet_id:      '1000000000008',
                                  flavor_id:            '1000000000009',
                                  security_group_id:    ''
    };

    var arbitrationProfileOptions = {availability_zones: []};

    $controller = _$controller_('arbitrationProfileFormController', {
      $scope: $scope,
      $location: $location,
      arbitrationProfileFormId: 1000000000001,
      miqService: miqService,
      arbitrationProfileData: arbitrationProfileData,
      arbitrationProfileOptions: arbitrationProfileOptions
    });
  }));

  var redirectUrl = '/ems_cloud/arbitration_profiles/1000000000001?db=ems_cloud';
  var profileOptions = Object({
                                name:                 'arbitrationProfileName',
                                description:          'arbitrationProfileDescription',
                                ems_id:               '1000000000001',
                                authentication_id:    '1000000000005',
                                availability_zone_id: '1000000000006',
                                cloud_network_id:     '1000000000007',
                                cloud_subnet_id:      '1000000000008',
                                flavor_id:            '1000000000009',
                                security_group_id:    ''
                              })

  describe('initialization', function() {
    it('sets the arbitrationProfileData name to the value returned via the http request', function() {
      expect($scope.arbitrationProfileModel.name).toEqual('arbitrationProfileName');
      expect($scope.arbitrationProfileModel.description).toEqual('arbitrationProfileDescription');
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.cancelClicked();
    });

    it('delegates to postService.cancelOperation', function() {
      var msg = "Edit of Arbitration Profile arbitrationProfileDescription was cancelled by the user";
      expect(postService.cancelOperation).toHaveBeenCalledWith(redirectUrl, msg);
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.arbitrationProfileModel.name = 'foo';
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
      };
      $scope.resetClicked();
    });

    it('resets value of name field to initial value', function() {
      expect($scope.arbitrationProfileModel.name).toEqual('arbitrationProfileName');
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('delegates to postService.saveRecord', function() {
      expect(postService.saveRecord).toHaveBeenCalledWith(
        '/api/arbitration_profiles/1000000000001',
        redirectUrl,
        profileOptions,
        'Arbitration Profile arbitrationProfileName was saved');
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.addClicked();
    });

    it('delegates to postService.saveRecord', function() {
      expect(postService.createRecord).toHaveBeenCalledWith(
        '/api/arbitration_profiles',
        redirectUrl,
        profileOptions,
        'Arbitration Profile arbitrationProfileName was added');
    });
  });
});
