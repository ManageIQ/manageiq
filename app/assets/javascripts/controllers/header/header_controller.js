angular.module('ManageIQ.notifications')
  .controller('headerController', HeaderCtrl);

HeaderCtrl.$inject = ['$scope', 'eventNotifications', '$timeout'];

function HeaderCtrl($scope, eventNotifications, $timeout) {
  var vm = this;

  var cookieId = 'miq-notification-drawer';
  vm.newNotifications = false;
  vm.notificationsDrawerShown = sessionStorage.getItem(cookieId + "-shown") == 'true';
  eventNotifications.setDrawerShown(vm.notificationsDrawerShown);

  vm.toggleNotificationsList = function () {
    vm.notificationsDrawerShown = !vm.notificationsDrawerShown;
    sessionStorage.setItem(cookieId + "-shown", vm.notificationsDrawerShown);
    eventNotifications.setDrawerShown(vm.notificationsDrawerShown);
  };

  var refresh = function() {
    $timeout(function() {
      vm.newNotifications = eventNotifications.state().unreadNotifications;
    });
  };

  var destroy = function() {
    eventNotifications.unregisterObserverCallback(refresh);
  };

  eventNotifications.registerObserverCallback(refresh);

  $scope.$on('destroy', destroy);

  refresh();
}
