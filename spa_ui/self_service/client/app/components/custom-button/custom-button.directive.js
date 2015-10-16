(function() {
  'use strict';

  angular.module('app.components')
    .directive('customButton', CustomButtonDirective);

  /** @ngInject */
  function CustomButtonDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {
        customActions: '=',
        actions: '=?'
      },
      link: link,
      templateUrl: 'app/components/custom-button/custom-button.html',
      controller: CustomButtonController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function CustomButtonController(Notifications, CollectionsApi) {
      var vm = this;

      vm.activate = activate;
      vm.customButtonAction = customButtonAction;

      function activate() {
        angular.forEach(vm.actions, processActionButtons);
      }

      function processActionButtons(buttonAction) {
        var temp = buttonAction.href.split('/api/')[1];
        buttonAction.collection = temp.split('/')[0];
        buttonAction.id = temp.split('/')[1];
      }

      function customButtonAction(button) {
        var assignedButton = {};
        angular.forEach(vm.actions, actionButtonMapping);

        if (assignedButton.method === 'post') {
          var data = {action: button.name};
          CollectionsApi.post(assignedButton.collection, assignedButton.id, {}, data).then(postSuccess, postFailure);
        } else if (assignedButton.method === 'delete') {
          CollectionsApi.delete(assignedButton.collection, assignedButton.id, {}).then(deleteSuccess, deleteFailure);
        } else {
          Notifications.error('Button action not supported.');
        }

        // Private functions
        function actionButtonMapping(buttonMatched) {
          if (buttonMatched.name.toLowerCase() === button.name.toLowerCase()) {
            assignedButton = buttonMatched;
          }
        }

        function postSuccess(response) {
          if (response.success === false) {
            Notifications.error(response.message);
          } else {
            Notifications.success(response.message);
          }
        }

        function postFailure() {
          Notifications.error('Action not able to submit.');
        }

        function deleteSuccess(response) {
          if (response.success === false) {
            Notifications.error(response.message);
          } else {
            Notifications.success(response.message);
          }
        }

        function deleteFailure() {
          Notifications.error('Action not able to submit.');
        }
      }
    }
  }
})();
