ManageIQ.angular.app.service('subscriptionService', ['$timeout', function($timeout) {
  this.subscribeToEventType = function(eventType, callback) {
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      if (event.eventType === eventType) {
        $timeout(function() {
          callback(event.response);
        });
      }
    });
  };
}]);
