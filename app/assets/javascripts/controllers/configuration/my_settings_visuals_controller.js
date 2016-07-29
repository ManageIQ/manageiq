ManageIQ.angular.app.controller('mySettingsVisualsController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
    var init = function() {
        $scope.afterGet = false;
        $scope.hideCancel = true;
        miqService.sparkleOn();
        $scope.mySettingsModel = {
            ems: true,
            ems_cloud: true,
            host: true,
            storage: true,
            vm: true,
            miq_template: true,
            quad_truncate: 'f',
            startpage: '',
            perpage_grid: '5',
            perpage_tile: '5',
            perpage_list: '5',
            perpage_reports: '5',
            display_reporttheme: '',
            display_timezone: '',
            display_locale: ''
        };

        $scope.model = 'mySettingsModel';
        $scope.newRecord = false;

        ManageIQ.angular.scope = $scope;

        $http.get('/configuration/get_visual_settings').success(function(data) {
            $scope.mySettingsModel = data;
            $scope.modelCopy = angular.copy( $scope.mySettingsModel );
            $scope.afterGet = true;
            miqService.sparkleOff();
        });
    };

    $scope.resetClicked = function() {
        $scope.$broadcast ('resetClicked');
        $scope.mySettingsModel = angular.copy( $scope.modelCopy );
        $scope.angularForm.$setPristine(true);
        miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.saveClicked = function() {
        miqService.sparkleOn();
        var url = '/configuration/set_visual_settings';
        miqService.miqAjaxButton(url, miqService.serializeModel($scope.mySettingsModel));
        miqService.sparkleOff();
        $scope.angularForm.$setPristine(true);
    };

    init();
}]);