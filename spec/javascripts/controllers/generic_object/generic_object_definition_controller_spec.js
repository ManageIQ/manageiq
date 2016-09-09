describe('genericObjectDefinitionFormController', function() {
  var $scope, $controller, $httpBackend, miqService, genericObjectSubscriptionService;
  var showAddFormCallback, treeClickCallback, rootTreeClickCallback;
  var treeData = {the: 'tree_data'};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_, _genericObjectSubscriptionService_) {
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    miqService = _miqService_;
    genericObjectSubscriptionService = _genericObjectSubscriptionService_;

    spyOn(window, 'sendDataWithRx');
    spyOn(miqService, 'sparkleOff');

    spyOn(genericObjectSubscriptionService, 'subscribeToShowAddForm').and.callFake(
      function(callback) {
        showAddFormCallback = callback;
      }
    );
    spyOn(genericObjectSubscriptionService, 'subscribeToTreeClicks').and.callFake(
      function(callback) {
        treeClickCallback = callback;
      }
    );
    spyOn(genericObjectSubscriptionService, 'subscribeToRootTreeclicks').and.callFake(
      function(callback) {
        rootTreeClickCallback = callback;
      }
    );

    $httpBackend.whenGET('tree_data').respond({tree_data: JSON.stringify(treeData)});
    $httpBackend.whenPOST('create').respond({message: "success"});

    $controller = _$controller_('genericObjectDefinitionFormController', {
      $scope: $scope,
      miqService: miqService,
      genericObjectSubscriptionService: genericObjectSubscriptionService
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets up the generic object definition model', function() {
      expect($scope.genericObjectDefinitionModel).toEqual(
        {name: '', description: ''}
      );
    });

    it('sets showAddForm to false', function() {
      expect($scope.showAddForm).toBe(false);
    });

    it('sets newRecord to true', function() {
      expect($scope.newRecord).toBe(true);
    });

    it('sets showSingleItem to false', function() {
      expect($scope.showSingleItem).toBe(false);
    });

    it('subscribes to show add form', function() {
      expect(genericObjectSubscriptionService.subscribeToShowAddForm).toHaveBeenCalledWith(showAddFormCallback);
    });

    it('subscribes to tree clicks', function() {
      expect(genericObjectSubscriptionService.subscribeToTreeClicks).toHaveBeenCalledWith(treeClickCallback);
    });

    it('subscribes to root tree clicks', function() {
      expect(genericObjectSubscriptionService.subscribeToRootTreeclicks).toHaveBeenCalledWith(rootTreeClickCallback);
    });

    describe('initialization showAddFormCallback', function() {
      var response = 'does not matter';

      beforeEach(function() {
        showAddFormCallback(response);
      });

      it('clears the name on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.name).toEqual('');
      });

      it('clears the description on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.description).toEqual('');
      });

      it('sets the showAddForm to true', function() {
        expect($scope.showAddForm).toEqual(true);
      });

      it('sends an event', function() {
        expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'deselectTreeNodes'});
      });
    });

    describe('initialization treeClickCallback', function() {
      var response = {name: 'name', description: 'description'};

      beforeEach(function() {
        treeClickCallback(response);
      });

      it('sets the name on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.name).toEqual('name');
      });

      it('sets the description on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.description).toEqual('description');
      });

      it('sets the showAddForm to false', function() {
        expect($scope.showAddForm).toEqual(false);
      });

      it('sets the showSingleItem to true', function() {
        expect($scope.showSingleItem).toEqual(true);
      });

      it('turns the sparkle off', function() {
        expect(miqService.sparkleOff).toHaveBeenCalled();
      });
    });

    describe('initialization rootTreeClickCallback', function() {
      var response = 'object list';

      beforeEach(function() {
        rootTreeClickCallback(response);
      });

      it('sets the genericObjectList', function() {
        expect($scope.genericObjectList).toEqual('object list');
      });

      it('sets showSingleItem to false', function() {
        expect($scope.showSingleItem).toEqual(false);
      });

      it('sets showAddForm to false', function() {
        expect($scope.showAddForm).toEqual(false);
      });
    });
  });

  describe('#clearForm', function() {
    it('clears the genericObjectDefinitionModel', function() {
      $scope.genericObjectDefinitionModel = {
        name: 'potato',
        description: 'potato'
      };

      $scope.clearForm();
      expect($scope.genericObjectDefinitionModel).toEqual({
        name: '',
        description: ''
      });
    });
  });

  describe('#listObjectClicked', function() {
    it('sends data', function() {
      $scope.listObjectClicked('name');
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'singleItemSelected', response: 'name'});
    });
  });

  describe('#addClicked', function() {
    var loadedDoneFunction;

    beforeEach(function() {
      $scope.genericObjectDefinitionModel = {
        name: 'name',
        description: 'description'
      };

      spyOn(miqService, 'jqueryRequest').and.callFake(function(url, options) {
        loadedDoneFunction = options.done;
      });

      $scope.addClicked();
      $httpBackend.flush();
    });

    it('sends the tree data', function() {
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'treeUpdated', response: treeData});
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {$setPristine: function() {}};
      $scope.genericObjectDefinitionModel = {
        name: 'name',
        description: 'description'
      };
      $scope.showAddForm = true;

      spyOn($scope.angularForm, '$setPristine');
      $scope.cancelClicked();
    });

    it('clears the form', function() {
      expect($scope.genericObjectDefinitionModel).toEqual({
        name: '',
        description: ''
      });
    });

    it('sets showAddForm to false', function() {
      expect($scope.showAddForm).toEqual(false);
    });

    it('sends data', function() {
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'cancelClicked'});
    });

    it('sets the form to pristine', function() {
      expect($scope.angularForm.$setPristine).toHaveBeenCalledWith(true);
    });
  });
});
