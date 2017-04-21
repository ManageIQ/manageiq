angular.module('miq.notifications').directive('miqNotificationDrawer', ['$window', '$timeout', function($window, $timeout) {
  'use strict';
  return {
    restrict: 'A',
    scope: {
      drawerHidden: '=?',
      allowExpand: '=?',
      drawerExpanded: '=?',
      drawerTitle: '@',
      notificationGroups: '=',
      actionButtonTitle: '@',
      actionButtonCallback: '=?',
      titleInclude: '@',
      headingInclude: '@',
      subheadingInclude: '@',
      notificationBodyInclude: '@',
      notificationFooterInclude: '@',
      customScope: '=?',
    },
    templateUrl: '/static/notification_drawer/notification-drawer.html',
    controller: ['$scope', function($scope) {
      if (! $scope.allowExpand || angular.isUndefined($scope.drawerExpanded)) {
        $scope.drawerExpanded = false;
      }

      $scope.limit = { notifications: 100 };
    }],
    link: function(scope, element) {
      scope.$watch('notificationGroups', function() {
        var openFound = false;
        scope.notificationGroups.forEach(function(group) {
          if (group.open) {
            if (openFound) {
              group.open = false;
            } else {
              openFound = true;
            }
          }
        });
      });

      scope.$watch('drawerHidden', function() {
        $timeout(function() {
          angular.element($window).triggerHandler('resize');
        }, 100);
      });

      scope.toggleCollapse = function(selectedGroup) {
        if (selectedGroup.open) {
          selectedGroup.open = false;
        } else {
          scope.notificationGroups.forEach(function(group) {
            group.open = false;
          });
          selectedGroup.open = true;
        }
      };

      scope.toggleExpandDrawer = function() {
        scope.drawerExpanded = ! scope.drawerExpanded;
      };

      if (scope.groupHeight) {
        element.find('.panel-group').css('height', scope.groupHeight);
      }
      if (scope.groupClass) {
        element.find('.panel-group').addClass(scope.groupClass);
      }
    },
  };
}]);
