ManageIQ.angular.app.service('subscriptionService', function() {
  this.subscribeToEventType = function(eventType, callback) {
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      if (event.eventType === eventType) {
        callback(event.response);
      }
    });
  };
});
