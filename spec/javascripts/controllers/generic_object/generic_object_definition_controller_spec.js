describe('genericObjectDefinitionFormController', function() {
  var $scope, $controller, $httpBackend, miqService, genericObjectSubscriptionService;
  var showAddFormCallback, showEditFormCallback, treeClickCallback, rootTreeClickCallback;
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
    spyOn(genericObjectSubscriptionService, 'subscribeToShowEditForm').and.callFake(
      function(callback) {
        showEditFormCallback = callback;
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
    $httpBackend.whenPOST('create', {id: '', name: 'name', description: 'description'}).respond({message: "success"});
    $httpBackend.whenPOST('save', {id: 123, name: 'new name', description: 'description'}).respond({message: "success"});

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
        {id: '', name: '', description: ''}
      );
    });

    it('sets showForm to false', function() {
      expect($scope.showForm).toBe(false);
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

      it('sets the newRecord to true', function() {
        expect($scope.newRecord).toEqual(true);
      });

      it('sets the showForm to true', function() {
        expect($scope.showForm).toEqual(true);
      });

      it('sends an event', function() {
        expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'deselectTreeNodes'});
      });
    });

    describe('initialization showEditFormCallback', function() {
      var response = 'does not matter';

      beforeEach(function() {
        showEditFormCallback(response);
      });

      it('copies the model to prepare for the reset button', function() {
        expect($scope.backupGenericObjectDefinitionModel).toEqual({name: '', description: ''});
      });

      it('sets the newRecord to false', function() {
        expect($scope.newRecord).toEqual(false);
      });

      it('sets the showForm to true', function() {
        expect($scope.showForm).toEqual(true);
      });

      it('sends an updateToolbarCount event', function() {
        expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'updateToolbarCount', countSelected: 0});
      });
    });

    describe('initialization treeClickCallback', function() {
      var response = {id: '123', name: 'name', description: 'description'};

      beforeEach(function() {
        treeClickCallback(response);
      });

      it('sets the id on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.id).toEqual('123');
      });

      it('sets the name on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.name).toEqual('name');
      });

      it('sets the description on the generic object definition model', function() {
        expect($scope.genericObjectDefinitionModel.description).toEqual('description');
      });

      it('sets the showForm to false', function() {
        expect($scope.showForm).toEqual(false);
      });

      it('sets the showSingleItem to true', function() {
        expect($scope.showSingleItem).toEqual(true);
      });

      it('sends an updateToolbarCount event', function() {
        expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'updateToolbarCount', countSelected: 1});
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

      it('sets showForm to false', function() {
        expect($scope.showForm).toEqual(false);
      });

      it('sends an updateToolbarCount event', function() {
        expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'updateToolbarCount', countSelected: 0});
      });
    });
  });

  describe('#clearForm', function() {
    it('clears the genericObjectDefinitionModel', function() {
      $scope.genericObjectDefinitionModel = {
        id: 'potato',
        name: 'potato',
        description: 'potato'
      };

      $scope.clearForm();
      expect($scope.genericObjectDefinitionModel).toEqual({
        id: '',
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

    it('sends more data', function() {
      $scope.listObjectClicked('name');
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'updateToolbarCount', countSelected: 1});
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $scope.genericObjectDefinitionModel = {
        id: '',
        name: 'name',
        description: 'description'
      };
    });

    it('makes a create http request', function() {
      $httpBackend.expectPOST('create', {name: 'name', description: 'description'}).respond(200, '');
      $scope.addClicked();
      $httpBackend.flush();
    });

    it('sends the tree data', function() {
      $scope.addClicked();
      $httpBackend.flush();
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'treeUpdated', response: treeData});
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.genericObjectDefinitionModel = {
        id: 123,
        name: 'new name',
        description: 'description'
      };
    });

    it('makes a save http request', function() {
      $httpBackend.expectPOST('save', {id: 123, name: 'new name', description: 'description'}).respond(200, '');
      $scope.saveClicked();
      $httpBackend.flush();
    });

    it('sends the tree data', function() {
      $scope.saveClicked();
      $httpBackend.flush();
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
      $scope.showForm = true;

      spyOn($scope.angularForm, '$setPristine');
      $scope.cancelClicked();
    });

    it('clears the form', function() {
      expect($scope.genericObjectDefinitionModel).toEqual({
        name: '',
        description: ''
      });
    });

    it('sets showForm to false', function() {
      expect($scope.showForm).toEqual(false);
    });

    it('sends data', function() {
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'cancelClicked'});
    });

    it('sends more data', function() {
      expect(window.sendDataWithRx).toHaveBeenCalledWith({eventType: 'updateToolbarCount', countSelected: 0});
    });

    it('sets the form to pristine', function() {
      expect($scope.angularForm.$setPristine).toHaveBeenCalledWith(true);
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {$setPristine: function() {}};
      $scope.genericObjectDefinitionModel = {
        name: 'name',
        description: 'description'
      };
      $scope.backupGenericObjectDefinitionModel = {
        name: 'backup name',
        description: 'backup description'
      };

      spyOn($scope.angularForm, '$setPristine');
      $scope.resetClicked();
    });

    it('copies the backup into the model', function() {
      expect($scope.genericObjectDefinitionModel).toEqual({name: 'backup name', description: 'backup description'});
    });

    it('sets the form to pristine', function() {
      expect($scope.angularForm.$setPristine).toHaveBeenCalledWith(true);
    });
  });
});
