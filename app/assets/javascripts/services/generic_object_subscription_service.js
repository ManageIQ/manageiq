ManageIQ.angular.app.service('genericObjectSubscriptionService', ['subscriptionService', function(subscriptionService) {
  this.subscribeToShowAddForm = function(callback) {
    subscriptionService.subscribeToEventType('showAddForm', callback);
  };

  this.subscribeToShowEditForm = function(callback) {
    subscriptionService.subscribeToEventType('showEditForm', callback);
  };

  this.subscribeToTreeClicks = function(callback) {
    subscriptionService.subscribeToEventType('treeClicked', callback);
  };

  this.subscribeToRootTreeclicks = function(callback) {
    subscriptionService.subscribeToEventType('rootTreeClicked', callback);
  };
}]);
