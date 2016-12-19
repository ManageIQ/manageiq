describe('subscriptionService', function() {
  var testService;
  var $timeout;
  var loadedReactionFunction;

  var test = {callback: function() {}};

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$timeout_, subscriptionService) {
    testService = subscriptionService;
    $timeout = _$timeout_;

    spyOn(test, 'callback');
    spyOn(window, 'listenToRx').and.callFake(function(callback) {
      loadedReactionFunction = callback;
    });
  }));

  afterEach(function() {
    $timeout.verifyNoPendingTasks();
  });

  describe('#subscribeToEventType', function() {
    beforeEach(function() {
      testService.subscribeToEventType('someEvent', test.callback);
    });

    it('subscribes', function() {
      expect(listenToRx).toHaveBeenCalledWith(loadedReactionFunction);
    });

    describe('#subscribeToEventType reaction function', function() {
      describe('when the event type matches the event type passed in', function() {
        beforeEach(function() {
          loadedReactionFunction({eventType: 'someEvent', response: 'the data'});
          $timeout.flush();
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
