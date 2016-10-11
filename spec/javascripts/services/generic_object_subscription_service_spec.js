describe('genericObjectSubscriptionService', function() {
  var testService;
  var subscriptionService;
  var callback = function() {};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_subscriptionService_, genericObjectSubscriptionService) {
    testService = genericObjectSubscriptionService;
    subscriptionService = _subscriptionService_;

    spyOn(subscriptionService, 'subscribeToEventType');
  }));

  describe('#subscribeToShowAddForm', function() {
    beforeEach(function() {
      testService.subscribeToShowAddForm(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('showAddForm', callback);
    });
  });

  describe('#subscribeToShowEditForm', function() {
    beforeEach(function() {
      testService.subscribeToShowEditForm(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('showEditForm', callback);
    });
  });

  describe('#subscribeToTreeClicks', function() {
    beforeEach(function() {
      testService.subscribeToTreeClicks(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('treeClicked', callback);
    });
  });

  describe('#subscribeToRootTreeclicks', function() {
    beforeEach(function() {
      testService.subscribeToRootTreeclicks(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('rootTreeClicked', callback);
    });
  });
});
