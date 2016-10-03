angular.module('miq.notifications')
  .controller('headerController', HeaderCtrl);

HeaderCtrl.$inject = ['$scope', 'eventNotifications', '$timeout'];

function HeaderCtrl($scope, eventNotifications, $timeout) {
  var vm = this;

  var cookieId = 'miq-notification-drawer';
  vm.newNotifications = false;
  vm.notificationsDrawerShown = sessionStorage.getItem(cookieId + "-shown") == 'true';
  eventNotifications.setDrawerShown(vm.notificationsDrawerShown);
  updateTooltip();

  vm.toggleNotificationsList = function () {
    vm.notificationsDrawerShown = !vm.notificationsDrawerShown;
    sessionStorage.setItem(cookieId + "-shown", vm.notificationsDrawerShown);
    eventNotifications.setDrawerShown(vm.notificationsDrawerShown);
  };

  var refresh = function() {
    $timeout(function() {
      vm.newNotifications = eventNotifications.state().unreadNotifications;
      updateTooltip(eventNotifications.state().groups);
    });
  };

  var destroy = function() {
    eventNotifications.unregisterObserverCallback(refresh);
  };

  function updateTooltip(groups) {
    var notificationCount = {
      text: 0
    };

    if (angular.isArray(groups)) {
      angular.forEach(groups, function(group) {
        notificationCount.text += group.unreadCount;
      });
    }

    vm.notificationsIndicatorTooltip = miqFormatNotification(__("%{count} unread notifications"),
                                                             {count: notificationCount});
  }

  eventNotifications.registerObserverCallback(refresh);

  $scope.$on('destroy', destroy);

  refresh();
}
