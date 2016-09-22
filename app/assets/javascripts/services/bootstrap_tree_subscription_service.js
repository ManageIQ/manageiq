ManageIQ.angular.app.service('bootstrapTreeSubscriptionService', ['subscriptionService', function(subscriptionService) {
  this.subscribeToTreeUpdates = function(callback) {
    subscriptionService.subscribeToEventType('treeUpdated', callback);
  };

  this.subscribeToCancelClicks = function(callback) {
    subscriptionService.subscribeToEventType('cancelClicked', callback);
  };

  this.subscribeToDeselectTreeNodes = function(callback) {
    subscriptionService.subscribeToEventType('deselectTreeNodes', callback);
  };

  this.subscribeToSingleItemSelected = function(callback) {
    subscriptionService.subscribeToEventType('singleItemSelected', callback);
  };
}]);
