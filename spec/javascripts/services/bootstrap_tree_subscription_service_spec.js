describe('bootstrapTreeSubscriptionService', function() {
  var testService;
  var subscriptionService;
  var callback = function() {};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_subscriptionService_, bootstrapTreeSubscriptionService) {
    testService = bootstrapTreeSubscriptionService;
    subscriptionService = _subscriptionService_;

    spyOn(subscriptionService, 'subscribeToEventType');
  }));

  describe('#subscribeToTreeUpdates', function() {
    beforeEach(function() {
      testService.subscribeToTreeUpdates(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('treeUpdated', callback);
    });
  });

  describe('#subscribeToCancelClicks', function() {
    beforeEach(function() {
      testService.subscribeToCancelClicks(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('cancelClicked', callback);
    });
  });

  describe('#subscribeToDeselectTreeNodes', function() {
    beforeEach(function() {
      testService.subscribeToDeselectTreeNodes(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('deselectTreeNodes', callback);
    });
  });

  describe('#subscribeToSingleItemSelected', function() {
    beforeEach(function() {
      testService.subscribeToSingleItemSelected(callback);
    });

    it('subscribes', function() {
      expect(subscriptionService.subscribeToEventType).toHaveBeenCalledWith('singleItemSelected', callback);
    });
  });
});
