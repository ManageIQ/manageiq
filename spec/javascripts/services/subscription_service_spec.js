describe('subscriptionService', function() {
  var testService;
  var loadedReactionFunction;

  var test = {callback: function() {}};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(subscriptionService) {
    testService = subscriptionService;

    spyOn(test, 'callback');
    spyOn(ManageIQ.angular.rxSubject, 'subscribe').and.callFake(function(callback) {
      loadedReactionFunction = callback;
    });
  }));

  describe('#subscribeToEventType', function() {
    beforeEach(function() {
      testService.subscribeToEventType('someEvent', test.callback);
    });

    it('subscribes', function() {
      expect(ManageIQ.angular.rxSubject.subscribe).toHaveBeenCalledWith(loadedReactionFunction);
    });

    describe('#subscribeToEventType reaction function', function() {
      describe('when the event type matches the event type passed in', function() {
        beforeEach(function() {
          loadedReactionFunction({eventType: 'someEvent', response: 'the data'});
        });

        it('calls the reaction function with the data', function() {
          expect(test.callback).toHaveBeenCalledWith('the data');
        });
      });

      describe('when the event type does not match', function() {
        beforeEach(function() {
          loadedReactionFunction({eventType: 'notSomeEvent', data: 'the data'});
        });

        it('does not call the reaction function', function() {
          expect(test.callback).not.toHaveBeenCalled();
        });
      });
    });
  });
});
