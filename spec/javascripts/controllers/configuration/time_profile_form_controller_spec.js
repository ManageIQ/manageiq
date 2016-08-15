describe('timeProfileFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'buildCalendar');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();

    $scope.timeProfileModel = {
      description: '',
      admin_user: false,
      restricted_time_profile: false,
      profile_type: '',
      profile_tz: '',
      all_days: false,
      all_hours: false,
      hours: [],
      days: []
    };

    $httpBackend = _$httpBackend_;
    var timeProfileResponse = {
      description: '',
      admin_user: false,
      restricted_time_profile: false,
      profile_type: '',
      profile_tz: '',
      all_days: false,
      all_hours: false,
      hours: [],
      days: []
    };

    $httpBackend.whenGET('/configuration/time_profile_form_fields/new').respond(timeProfileResponse);
    $controller = _$controller_('timeProfileFormController', {
      $scope: $scope,
      timeProfileFormId: 'new',
      miqService: miqService
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    beforeEach(function() {
      $httpBackend.flush();
    });
    describe('when the timeProfileFormId is new', function() {
      it('sets the name to blank', function () {
        expect($scope.timeProfileModel.description).toEqual('');
      });
      it('sets the admin_user to false', function () {
        expect($scope.timeProfileModel.admin_user).toBeFalsy();
      });
      it('sets the restricted_time_profile to false', function () {
        expect($scope.timeProfileModel.restricted_time_profile).toBeFalsy();
      });
      it('sets the profile_type to blank', function () {
        expect($scope.timeProfileModel.profile_type).toEqual('');
      });
      it('sets the profile_tz to blank', function () {
        expect($scope.timeProfileModel.profile_tz).toEqual('');
      });
      it('sets the all_days to false', function () {
        expect($scope.timeProfileModel.all_days).toBeFalsy();
      });
      it('sets the all_hours to blank', function () {
        expect($scope.timeProfileModel.all_hours).toBeFalsy();
      });
    });
  });

  describe('when the timeProfileFormId is an id', function() {
    var timeProfileFormResponse = {
      description: 'TimeProfileTest',
      admin_user: true,
      restricted_time_profile: false,
      profile_type: 'user',
      profile_tz: 'Alaska',
      rollup_daily: true,
      all_days: true,
      all_hours: true,
      days: [0, 1, 2, 3, 4, 5, 6],
      hours: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
    };

    beforeEach(inject(function(_$controller_) {
      $httpBackend.whenGET('/configuration/time_profile_form_fields/12345').respond(timeProfileFormResponse);
      $controller = _$controller_('timeProfileFormController',
        {
          $scope: $scope,
          timeProfileFormId: '12345',
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to blank', function () {
      expect($scope.timeProfileModel.description).toEqual('TimeProfileTest');
    });
    it('sets the admin_user to false', function () {
      expect($scope.timeProfileModel.admin_user).toBeTruthy();
    });
    it('sets the restricted_time_profile to false', function () {
      expect($scope.timeProfileModel.restricted_time_profile).toBeFalsy();
    });
    it('sets the profile_type to blank', function () {
      expect($scope.timeProfileModel.profile_type).toEqual('user');
    });
    it('sets the profile_tz to blank', function () {
      expect($scope.timeProfileModel.profile_tz).toEqual('Alaska');
    });
    it('sets the all_days to false', function () {
      expect($scope.timeProfileModel.all_days).toBeTruthy();
    });
    it('sets the all_hours to blank', function () {
      expect($scope.timeProfileModel.all_hours).toBeTruthy();
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('turns the spinner on twice', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(2);
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });
  });
});
