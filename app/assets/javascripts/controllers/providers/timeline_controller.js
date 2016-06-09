(function(){

  function subscribeToSubject() {
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      this.onNewData(event);
    }.bind(this),
    function (err) {
      console.log('Error: ' + err);
    },
    function () {
      console.log('Completed');
    });
  }

  var TimelineController = function($scope) {
    this.$scope = $scope;
    subscribeToSubject.bind(this)();
  }

  TimelineController.prototype.onNewData = function(event) {
    if (event.data.events) {
      this.timelineData = event.data.events;
      this.timelineSettings = event.settings[0];
      this.timelineSettings.startTimestamp = new Date(this.timelineSettings.st_time).getTime();
      this.timelineSettings.endTimestamp = new Date(this.timelineSettings.end_time).getTime();
      _.each(this.timelineData, function(item) {
        item.html = item.description;
        item.timestamp = new Date(item.start).getTime();
      }.bind(this))
      this.$scope.$apply();
    }
  }

  TimelineController.$inject = ['$scope'];

  miqHttpInject(angular.module('miq.timeline'))
  .controller('miqTimlineController', TimelineController)
})();
