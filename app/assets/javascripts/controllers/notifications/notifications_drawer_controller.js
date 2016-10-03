angular.module('miq.notifications')
  .controller('notificationsDrawerController', NotificationsDrawerCtrl);

NotificationsDrawerCtrl.$inject = ['$scope', 'eventNotifications', '$timeout'];

function NotificationsDrawerCtrl($scope, eventNotifications, $timeout) {
  var vm = this;
  var cookieId = 'miq-notification-drawer';
  vm.notificationGroups = [];
  vm.drawerExpanded = sessionStorage.getItem(cookieId + "-expanded") == 'true';
  vm.notificationsDrawerShown = eventNotifications.state().drawerShown;

  var watchExpanded = $scope.$watch(angular.bind(vm, function () {
    return vm.drawerExpanded;
  }), function () {
    sessionStorage.setItem(cookieId + "-expanded", vm.drawerExpanded);
  });

  var addGroupWatchers = function () {
    angular.forEach(vm.notificationGroups, function (group, index) {
      if (group.watcher) {
        group.watcher();
      }
      group.watcher = $scope.$watch(angular.bind(vm, function () {
        return vm.notificationGroups[index];
      }), function(newVal) {
        sessionStorage.setItem(cookieId + "-" + newVal.notificationType + "-open", newVal.open);
      }, true);
    });
  };

  var clearGroupWatchers = function() {
    angular.forEach(vm.notificationGroups, function (group) {
      if (angular.isFunction(group.watcher)) {
        group.watcher();
      }
    });
  };

  var updatePosition = function() {
    var hasVerticalScrollbar,
        scrollContent = angular.element('#main-content'),
        miqNotificationsDrawer = angular.element('#miq-notifications-drawer .drawer-pf');
    if (scrollContent && scrollContent.length == 1 && miqNotificationsDrawer && miqNotificationsDrawer.length == 1) {
      hasVerticalScrollbar = scrollContent[0].scrollHeight > scrollContent[0].clientHeight;
      if (hasVerticalScrollbar) {
        angular.element(miqNotificationsDrawer).addClass('vertical-scroll');
      } else {
        angular.element(miqNotificationsDrawer).removeClass('vertical-scroll');
      }

    }
  };

  var watchPositioning = function () {
    var scrollContent = angular.element('#main-content');
    if (scrollContent && scrollContent.length == 1) {
      updatePosition();
      scrollContent.off('resize', updatePosition);
      scrollContent.on('resize', updatePosition);
    }
  };

  var refreshNotifications = function() {
    clearGroupWatchers();

    vm.notificationGroups = eventNotifications.state().groups;
    angular.forEach($scope.notificationGroups, function(group) {
      group.open = sessionStorage.getItem(cookieId + "-" + group.notificationType + "-open") == 'true';
    });

    addGroupWatchers();
  };

  var refresh = function() {
    $timeout(function() {
      refreshNotifications();
      vm.notificationsDrawerShown = eventNotifications.state().drawerShown;
    });
  };

  var destroy = function() {
    eventNotifications.unregisterObserverCallback(refresh);
    groupsWatcher();
    clearGroupWatchers();
    watchExpanded();
  };

  eventNotifications.registerObserverCallback(refresh);

  $scope.$on('destroy', destroy);

  if (vm.notificationsDrawerShown) {
    angular.element(document).ready(watchPositioning);
  }
  angular.element(window).resize(watchPositioning);

  vm.customScope = {};

  vm.customScope.getNotficationStatusIconClass = function(notification) {
    var retClass = '';
    if (notification && notification.data && notification.data.type) {
      if (notification.data.type == 'info') {
        retClass = "pficon pficon-info";
      } else if ((notification.data.type == 'error') || (notification.data.type == 'danger')) {
        retClass = "pficon pficon-error-circle-o";
      } else if (notification.data.type == 'warning') {
        retClass = "pficon pficon-warning-triangle-o";
      } else if ((notification.data.type == 'success') || (notification.data.type == 'ok')) {
        retClass = "pficon pficon-ok";
      }
    }

    return retClass;
  };

  vm.customScope.markNotificationRead = function(notification, group) {
    eventNotifications.markRead(notification, group);
  };

  vm.customScope.clearNotification = function(notification, group) {
    eventNotifications.clear(notification, group);
  };

  vm.customScope.markAllRead = function(group) {
    eventNotifications.markAllRead(group);
  };
  vm.customScope.clearAllNotifications = function(group) {
    eventNotifications.clearAll(group);
  };

  refresh();
}
