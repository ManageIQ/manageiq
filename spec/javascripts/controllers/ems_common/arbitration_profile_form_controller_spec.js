describe('arbitrationProfileFormController', function() {
  var $scope, $controller, postService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, $location, _$controller_, miqService, _postService_, arbitrationProfileDataFactory) {
    postService = _postService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    spyOn(postService, 'cancelOperation');
    spyOn(postService, 'saveRecord');
    spyOn(postService, 'createRecord');
    $scope = $rootScope.$new();

    spyOn($location, 'absUrl').and.returnValue('/ems_cloud/arbitration_profile_edit/1000000000001?db=ems_cloud');
    spyOn(window, 'queryParam').and.returnValue('1000000000001');

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

    spyOn(arbitrationProfileDataFactory, 'getArbitrationProfileData').and.returnValue(Promise.resolve(arbitrationProfileData));

    $controller = _$controller_('arbitrationProfileFormController', {
      $scope: $scope,
      arbitrationProfileFormId: 1000000000001
    });
  }));

  var redirectUrl = '/ems_cloud/arbitration_profiles/1000000000001?db=ems_cloud';
  var profileOptions = {
    name:                 'arbitrationProfileName',
    description:          'arbitrationProfileDescription',
    ems_id:               '1000000000001',
    authentication_id:    '1000000000005',
    availability_zone_id: '1000000000006',
    cloud_network_id:     '1000000000007',
    cloud_subnet_id:      '1000000000008',
    flavor_id:            '1000000000009',
    security_group_id:    ''
  }

  describe('initialization', function() {
    it('sets the arbitrationProfileData name to the value returned via the http request', function(done) {
      setTimeout(function () {
        expect($scope.arbitrationProfileModel.name).toEqual('arbitrationProfileName');
        expect($scope.arbitrationProfileModel.description).toEqual('arbitrationProfileDescription');
        done();
      });
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      setTimeout($scope.cancelClicked);
    });

    it('delegates to postService.cancelOperation', function(done) {
      setTimeout(function () {
        var msg = "Edit of Arbitration Profile arbitrationProfileDescription was cancelled by the user";
        expect(postService.cancelOperation).toHaveBeenCalledWith(redirectUrl, msg);
        done();
      });
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.arbitrationProfileModel.name = 'arbitrationProfileName';
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
      };
      setTimeout($scope.resetClicked);
    });

    it('resets value of name field to initial value', function(done) {
      setTimeout(function() {
        expect($scope.arbitrationProfileModel.name).toEqual('arbitrationProfileName');
        done();
      });
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      setTimeout($scope.saveClicked);
    });

    it('delegates to postService.saveRecord', function(done) {
      setTimeout(function() {
        expect(postService.saveRecord).toHaveBeenCalledWith(
          '/api/arbitration_profiles/1000000000001',
          redirectUrl,
          profileOptions,
          'Arbitration Profile arbitrationProfileName was saved'
        );
        done();
      });
    });
  });

  describe('#addClicked', function() {
    beforeEach(function () {
      setTimeout($scope.addClicked);
    });

    it('delegates to postService.createRecord', function (done) {
      setTimeout(function () {
        expect(postService.createRecord).toHaveBeenCalledWith(
          '/api/arbitration_profiles',
          redirectUrl,
          profileOptions,
          'Arbitration Profile arbitrationProfileName was added'
        );
        done();
      });
    });
  });
});
