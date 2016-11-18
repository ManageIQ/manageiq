ManageIQ.angular.app.controller('timelineOptionsController', ['$http', '$scope', 'miqService', 'url', 'categories', function($http, $scope, miqService, url, categories) {
    var init = function() {
        $scope.reportModel = {
            tl_show: 'timeline',
            tl_categories: ['Power Activity'],
            tl_timerange: 'weeks',
            tl_timepivot: 'ending',
            tl_result: 'success',
            tl_range_count: 1,
            tl_date: new Date(ManageIQ.calendar.calDateTo)
        };

        $scope.afterGet  = true;
        $scope.dateOptions = {
            autoclose: true,
            todayHighlight: true,
            orientation: 'bottom'
        };
        ManageIQ.angular.scope = $scope;
        $scope.availableCategories = categories;
    };

    $scope.eventTypeUpdated = function() {
        $scope.reportModel.tl_categories = [];
    };

    $scope.countDecrement = function() {
        if($scope.reportModel.tl_range_count > 1) {
            $scope.reportModel.tl_range_count--;
        }
    };

    $scope.countIncrement = function() {
        $scope.reportModel.tl_range_count++;
    };

    $scope.applyButtonClicked = function() {
        if($scope.reportModel.tl_categories.length === 0) {
            return;
        }
        
        // process selections
        if($scope.reportModel.tl_timerange === 'days') {
            $scope.reportModel.tl_typ = 'Hourly';
            $scope.reportModel.tl_days = $scope.reportModel.tl_range_count;
        } else {
            $scope.reportModel.tl_typ = 'Daily';
            if($scope.reportModel.tl_timerange === 'weeks') {
                $scope.reportModel.tl_days = $scope.reportModel.tl_range_count * 7;
            } else {
                $scope.reportModel.tl_days = $scope.reportModel.tl_range_count * 30;
            }
        }

        var selectedDay = moment($scope.reportModel.tl_date),
            startDay = selectedDay.clone(),
            endDay = selectedDay.clone();

        if($scope.reportModel.tl_timepivot === "starting") {
            endDay.add($scope.reportModel.tl_days, 'days').toDate();
            $scope.reportModel.miq_date = endDay.format('MM/DD/YYYY');
        } else if($scope.reportModel.tl_timepivot === "centered") {
            var enddays = Math.ceil($scope.reportModel.tl_days/2);
            startDay.subtract(enddays, 'days').toDate();
            endDay.add(enddays, 'days').toDate();
            $scope.reportModel.miq_date = endDay.format('MM/DD/YYYY');

        }  else if($scope.reportModel.tl_timepivot === "ending") {
            startDay.subtract($scope.reportModel.tl_days, 'days');
            $scope.reportModel.miq_date = endDay.format('MM/DD/YYYY');
        }
        ManageIQ.calendar.calDateFrom = startDay.toDate();
        ManageIQ.calendar.calDateTo = endDay.toDate();
        if($scope.reportModel.tl_show === 'timeline') {
            if($scope.reportModel.showDetailedEvents) {
                $scope.reportModel.tl_fl_typ = 'detail';
            } else {
                $scope.reportModel.tl_fl_typ = 'critical';
            }
        }
        miqService.sparkleOn();
        miqService.miqAsyncAjaxButton(url, miqService.serializeModel($scope.reportModel));
    };

    init();
}]);
