(function(){

  function subscribeToSubject() {
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      this.onNewData(event);
    }.bind(this),
    function (err) {
      console.error('Angular RxJs Error: ', err);
    },
    function () {
      console.debug('Angular RxJs subject completed, no more events to catch.');
    });
  }

  var TimelineController = function($scope) {
    this.$scope = $scope;
    subscribeToSubject.bind(this)();
    this.$scope.$on(Charts.EventNames.TIMELINE_CHART_TIMERANGE_CHANGED, function (event, data) {
      this.filterData(data[0].getTime(), data[1].getTime());
    }.bind(this));
  }

  TimelineController.prototype.filterData = function(startTime, endTime) {
    this.timelineSettings.startTimestamp = startTime;
    this.timelineSettings.endTimestamp = endTime;
    this.timelineData.filter(function (value) {
        return new Date(value.timestamp) >= this.timelineSettings.startTimestamp
          && new Date(value.timestamp) <= this.timelineSettings.endTimestamp;
      }.bind(this));
    this.$scope.$digest();
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
