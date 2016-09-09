describe('bootstrapTreeController', function() {
  var treeUpdateCallback, cancelClickCallback, deselectTreeNodeCallback, singleItemSelectedCallback;
  var allNodes, innerNode;
  var onNodeSelectedCallback = function() {};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _bootstrapTreeSubscriptionService_) {
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    bootstrapTreeSubscriptionService = _bootstrapTreeSubscriptionService_;

    spyOn(window, 'sendDataWithRx');

    spyOn(bootstrapTreeSubscriptionService, 'subscribeToTreeUpdates').and.callFake(
      function(callback) {
        treeUpdateCallback = callback;
      }
    );
    spyOn(bootstrapTreeSubscriptionService, 'subscribeToCancelClicks').and.callFake(
      function(callback) {
        cancelClickCallback = callback;
      }
    );
    spyOn(bootstrapTreeSubscriptionService, 'subscribeToDeselectTreeNodes').and.callFake(
      function(callback) {
        deselectTreeNodeCallback = callback;
      }
    );
    spyOn(bootstrapTreeSubscriptionService, 'subscribeToSingleItemSelected').and.callFake(
      function(callback) {
        singleItemSelectedCallback = callback;
      }
    );

    var treeData = {tree: 'data'};
    var railsControllerName = 'railsController';
    allNodes = {nodes: [innerNode]};
    innerNode = {text: 'nodeName'};

    spyOn($.fn, 'treeview').and.callFake(function(options, node) {
      if (options.onNodeSelected) {
        onNodeSelectedCallback = options.onNodeSelected;
      }
      if (options === 'getSelected') {
        return 'all nodes';
      }
      if (options === 'getNodes') {
        return [allNodes];
      }
    });

    $httpBackend.whenGET('/railsController/object_data/123').respond({data: 'single item'});
    $httpBackend.whenGET('/railsController/all_object_data').respond({data: 'all items'});

    $controller = _$controller_('bootstrapTreeController', {
      $scope: $scope,
      initialTreeData: treeData,
      railsControllerName: railsControllerName,
      bootstrapTreeSubscriptionService: bootstrapTreeSubscriptionService
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets up the tree view', function() {
      expect($.fn.treeview).toHaveBeenCalledWith({
        collapseIcon: 'fa fa-angle-down',
        data: {tree: 'data'},
        expandIcon: 'fa fa-angle-right',
        nodeIcon: 'fa fa-folder',
        showBorder: false,
        onNodeSelected: onNodeSelectedCallback
      });
    });

    it('selects the root node', function() {
      expect($.fn.treeview).toHaveBeenCalledWith('selectNode', allNodes);
    });

    it('uses the correct selector', function() {
      expect($.fn.treeview.calls.mostRecent().object.selector).toEqual('#bootstrap-tree-left-nav');
    });

    it('subscribes to tree updates', function() {
      expect(bootstrapTreeSubscriptionService.subscribeToTreeUpdates).toHaveBeenCalledWith(treeUpdateCallback);
    });

    it('subscribes to cancel clicks', function() {
      expect(bootstrapTreeSubscriptionService.subscribeToCancelClicks).toHaveBeenCalledWith(cancelClickCallback);
    });

    it('subscribes to deselect tree nodes', function() {
      expect(bootstrapTreeSubscriptionService.subscribeToDeselectTreeNodes).toHaveBeenCalledWith(deselectTreeNodeCallback);
    });

    it('subscribes to single item selected', function() {
      expect(bootstrapTreeSubscriptionService.subscribeToSingleItemSelected).toHaveBeenCalledWith(singleItemSelectedCallback);
    });

    describe('nodeSelectedCallback', function() {
      describe('when there is an id in the data', function() {
        beforeEach(function() {
          onNodeSelectedCallback('nothing', {id: 123});
          $httpBackend.flush();
        });

        it('sends a tree clicked event', function() {
          expect(window.sendDataWithRx).toHaveBeenCalledWith({
            eventType: 'treeClicked',
            response: {data: 'single item'}
          });
        });
      });

      describe('when there is not an id in the data', function() {
        beforeEach(function() {
          onNodeSelectedCallback('nothing', {});
          $httpBackend.flush();
        });

        it('sends a tree clicked event', function() {
          expect(window.sendDataWithRx).toHaveBeenCalledWith({
            eventType: 'rootTreeClicked',
            response: {data: 'all items'}
          });
        });
      });
    });

    describe('treeUpdateCallback', function() {
      beforeEach(function() {
        treeUpdateCallback('some data');
      });

      it('re-sets-up the bootstrap tree', function() {
        expect($.fn.treeview).toHaveBeenCalledWith({
          collapseIcon: 'fa fa-angle-down',
          data: 'some data',
          expandIcon: 'fa fa-angle-right',
          nodeIcon: 'fa fa-folder',
          showBorder: false,
          onNodeSelected: onNodeSelectedCallback
        });
      });

      it('uses the correct selector', function() {
        expect($.fn.treeview.calls.mostRecent().object.selector).toEqual('#bootstrap-tree-left-nav');
      });
    });

    describe('cancelClickCallback', function() {
      beforeEach(function() {
        cancelClickCallback();
      });

      it('selects the root node', function() {
        expect($.fn.treeview).toHaveBeenCalledWith('selectNode', allNodes);
      });

      it('uses the correct selector', function() {
        expect($.fn.treeview.calls.mostRecent().object.selector).toEqual('#bootstrap-tree-left-nav');
      });
    });

    describe('deselectTreeNodeCallback', function() {
      beforeEach(function() {
        deselectTreeNodeCallback();
      });

      it('gets all selected nodes in the treeview', function() {
        expect($.fn.treeview).toHaveBeenCalledWith('getSelected');
      });

      it('unselects all selected nodes', function() {
        expect($.fn.treeview).toHaveBeenCalledWith('unselectNode', 'all nodes');
      });

      it('uses the correct selector', function() {
        expect($.fn.treeview.calls.mostRecent().object.selector).toEqual('#bootstrap-tree-left-nav');
      });
    });

    describe('singleItemSelectedCallback', function() {
      describe('when the node text is equal to the response', function() {
        beforeEach(function() {
          singleItemSelectedCallback('nodeName');
        });

        it('finds the selected node from the list of all nodes', function() {
          expect($.fn.treeview).toHaveBeenCalledWith('selectNode', innerNode);
        });
      });

      describe('when the node text is not equal to the response', function() {
        beforeEach(function() {
          singleItemSelectedCallback('not nodeName');
        });

        it('gets the root node', function() {
          expect($.fn.treeview).toHaveBeenCalledWith('getNodes');
        });

        it('does not select the node', function() {
          expect($.fn.treeview).not.toHaveBeenCalledWith('selectNode', innerNode);
        });
      });
    });
  });
});
