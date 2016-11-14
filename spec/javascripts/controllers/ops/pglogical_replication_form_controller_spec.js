describe('pglogicalReplicationFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.pglogicalReplicationModel = {
      replication_type: 'none',
      subscriptions   : [],
      exclusion_list  : ""
    };
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('pglogicalReplicationFormController', {
      $scope: $scope,
      pglogicalReplicationFormId: 'new',
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var pglogicalReplicationFormResponse = {
      replication_type: 'none',
      subscriptions   : [],
      exclusion_list  : ""
    };
    $httpBackend.whenGET('/ops/pglogical_subscriptions_form_fields/new').respond(pglogicalReplicationFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the replication type returned with http request', function() {
      expect($scope.pglogicalReplicationModel.replication_type).toEqual('none');
    });

    it('sets the subscriptions value returned with http request', function() {
      expect($scope.pglogicalReplicationModel.subscriptions).toEqual([]);
    });

    it('sets the exclusion list to the value returned by the http request', function() {
      expect($scope.pglogicalReplicationModel.exclusion_list).toEqual("");
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){}
      };
      $scope.resetClicked();
    });

    it('sets total spinner count to be 1', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      var submitContent = {
        replication_type: $scope.pglogicalReplicationModel.replication_type,
        subscriptions:    $scope.pglogicalReplicationModel.subscriptions,
        exclusion_list:   $scope.pglogicalReplicationModel.exclusion_list};

      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/pglogical_save_subscriptions/new?button=save', submitContent);
    });
  });
});
