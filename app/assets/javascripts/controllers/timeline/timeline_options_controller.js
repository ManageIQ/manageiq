ManageIQ.angular.app.controller('timelineOptionsController', ['$http', '$scope', 'miqService', 'url', function($http, $scope, miqService, url) {
    var init = function() {
        $scope.reportModel = {
            tl_show: 'timeline',
            tl_categories: ['Power Activity'],
            tl_timerange: 'one_week',
            tl_timepivot: 'ending',
            tl_date: new Date(ManageIQ.calendar.calDateTo)
        };

        $scope.afterGet  = true;
        $scope.dateOptions = {
            autoclose: true,
            todayHighlight: true
        };
        ManageIQ.angular.scope = $scope;
        $scope.applyButtonClicked();
    };

    $scope.eventTypeUpdated = function() {
        $scope.reportModel.tl_categories = [];
    };

    $scope.applyButtonClicked = function() {
        if($scope.reportModel.tl_categories.length === 0) {
            return;
        }

        // process selections
        if($scope.reportModel.tl_timerange === 'one_hour' || $scope.reportModel.tl_timerange === 'one_day') {
            $scope.reportModel.tl_typ = 'Hourly';
            $scope.reportModel.tl_days = 1;
        } else {
            $scope.reportModel.tl_typ = 'Daily';
            if($scope.reportModel.tl_timerange === 'one_week') {
                $scope.reportModel.tl_days = 7;
            } else {
                $scope.reportModel.tl_days = 31;
            }
        }

        var startDate = moment(ManageIQ.calendar.calDateFrom);
        var endDate = moment(ManageIQ.calendar.calDateTo);
        $scope.reportModel.tl_days = endDate.diff(startDate, 'days');
        $scope.reportModel.miq_date = ManageIQ.calendar.calDateTo;
        // Calculate miq_date based on user's selection
        /*
        var selectedDay = moment($scope.reportModel.tl_date);
        if($scope.reportModel.tl_timepivot === "starting") {
            $scope.reportModel.miq_date = selectedDay.add($scope.reportModel.tl_days, 'days').format('MM/DD/YYYY');
        } else if($scope.reportModel.tl_timepivot === "centered") {
            var enddays = Math.ceil($scope.reportModel.tl_days/2);
            $scope.reportModel.miq_date = selectedDay.add(enddays, 'days').format('MM/DD/YYYY');
        }  else if($scope.reportModel.tl_timepivot === "ending") {
            $scope.reportModel.miq_date = selectedDay.format('MM/DD/YYYY');
        }
        */

        if($scope.reportModel.tl_show !== 'timeline') {
            if($scope.reportModel.showSuccessfulEvents && $scope.reportModel.showFailedEvents) {
                $scope.reportModel.tl_result = 'both';
            } else if($scope.reportModel.showFailedEvents) {
                $scope.reportModel.tl_result = 'failure';
            } else {
                $scope.reportModel.tl_result = 'success';
            }
        } else {
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
