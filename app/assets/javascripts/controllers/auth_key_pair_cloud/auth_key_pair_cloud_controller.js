ManageIQ.angular.app.controller('keyPairCloudFormController', ['$http', '$scope', 'keyPairFormId', 'miqService', function($http, $scope, keyPairFormId, miqService) {
    var init = function() {
        $scope.keyPairModel = {
            name: '',
            public_key: '',
            ems_id: ''
        };
        $scope.formId = keyPairFormId;
        $scope.afterGet = false;
        $scope.modelCopy = angular.copy( $scope.keyPairModel );
        $scope.model = 'keyPairModel';
        $scope.ems_choices = [];
        ManageIQ.angular.scope = $scope;

        miqService.sparkleOn();
        $http.get('/auth_key_pair_cloud/ems_form_choices').success(function(data) {
            $scope.ems_choices = data.ems_choices;
            if($scope.ems_choices.length > 0) {
                $scope.keyPairModel.ems = $scope.ems_choices[0];
            }
            $scope.afterGet = true;
            miqService.sparkleOff();
        });

        if (keyPairFormId == 'new') {
            $scope.newRecord = true;
        } else {
            $scope.newRecord = false;
        }
    };

    var keyPairEditButtonClicked = function(buttonName, serializeFields) {
        miqService.sparkleOn();

        //todo - save values to server
        var url = '/auth_key_pair_cloud/create/' + keyPairFormId + '?button=' + buttonName;
        $scope.keyPairModel.ems_id = $scope.keyPairModel.ems.id;
        var moreUrlParams = $.param(miqService.serializeModel($scope.keyPairModel));
        if(moreUrlParams)
            url += '&' + decodeURIComponent(moreUrlParams);
        miqService.miqAjaxButton(url, false);
        miqService.sparkleOff();
    };

    $scope.cancelClicked = function() {
        keyPairEditButtonClicked('cancel');
        $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
        $scope.keyPairModel = angular.copy( $scope.modelCopy );
        $scope.angularForm.$setPristine(true);
        miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.saveClicked = function() {
        keyPairEditButtonClicked('save', true);
        $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = function() {
        $scope.saveClicked();
    };

    init();
}]);