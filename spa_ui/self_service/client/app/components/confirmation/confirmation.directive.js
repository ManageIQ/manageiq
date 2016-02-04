(function() {
  'use strict';

  angular.module('app.components')
    .directive('confirmation', ConfirmationDirective);

  /** @ngInject */
  function ConfirmationDirective($position, $window) {
    var directive = {
      restrict: 'AE',
      scope: {
        position: '@?confirmationPosition',
        title: '@?confirmationTitle',
        message: '@?confirmationMessage',
        trigger: '@?confirmationTrigger',
        ok: '@?confirmationOkText',
        cancel: '@?confirmationCancelText',
        onOk: '&confirmationOnOk',
        onCancel: '&?confirmationOnCancel',
        okStyle: '@?confirmationOkStyle',
        confirmIf: '=?confirmationIf',
        showCancel: '=?confirmationShowCancel'
      },
      link: link,
      controller: ConfirmationController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate({
        getOffset: getOffset,
        getPosition: getPosition,
        size: getSizeOfConfirmation()
      });

      element.on(attrs.confirmationTrigger || 'click', vm.onTrigger);

      function getOffset() {
        return $window.pageYOffset;
      }

      function getPosition() {
        return $position.offset(element);
      }

      // Private

      function getSizeOfConfirmation() {
        var height;
        var width;
        var sizerMessage = attrs.confirmationMessage || __('For Sizing');
        var sizer = angular.element('<div class="confirmation__dialog"><div class="confirmation__content">' +
          '<div class="confirmation__body"><p class="confirmation_message">' + sizerMessage +
          '</p><div class="confirmation_buttons">' +
          '<button type="button" class="confirmation__button btn-rounded">' +
          __('For Sizing') +
          '</button>' +
          '</div></div></div></div>');

        sizer.css('visibility', 'hidden');
        element.parent().append(sizer);
        height = sizer.prop('offsetHeight');
        width = sizer.prop('offsetWidth');
        sizer.detach();

        return {
          height: height,
          width: width
        };
      }
    }

    /** @ngInject */
    function ConfirmationController($scope, $modal) {
      var vm = this;

      var modalOptions = {
        templateUrl: 'app/components/confirmation/confirmation.html',
        scope: $scope
      };

      vm.top = 0;
      vm.left = 0;

      vm.activate = activate;
      vm.onTrigger = onTrigger;

      function activate(api) {
        angular.extend(vm, api);
        vm.position = angular.isDefined(vm.position) ? vm.position : 'top-center';
        vm.title = angular.isDefined(vm.title) ? vm.title : false;
        vm.message = angular.isDefined(vm.message) ? vm.message : __('Are you sure you wish to proceed?');
        vm.ok = angular.isDefined(vm.ok) ? vm.ok : 'Ok';
        vm.cancel = angular.isDefined(vm.cancel) ? vm.cancel : __('Cancel');
        vm.onCancel = angular.isDefined(vm.onCancel) ? vm.onCancel : angular.noop;
        vm.okClass = angular.isDefined(vm.okStyle) ? 'btn-' + vm.okStyle : '';
        vm.confirmIf = angular.isDefined(vm.confirmIf) ? vm.confirmIf : true;
        vm.showCancel = angular.isDefined(vm.showCancel) ? vm.showCancel : true;
      }

      function onTrigger() {
        var position = getModalPosition();
        var modal;

        if (vm.confirmIf) {
          vm.left = position.left;
          vm.top = position.top - vm.getOffset();

          modal = $modal.open(modalOptions);
          modal.result.then(onOk, onCancel);
        } else {
          vm.onOk();
        }

        function onOk() {
          vm.onOk();
        }

        function onCancel() {
          vm.onCancel();
        }
      }

      // Grafted in from ui.bootstraps $position.positionElements()
      function getModalPosition() {
        var posParts = vm.position.split('-');
        var pos0 = posParts[0];
        var pos1 = posParts[1] || 'center';
        var hostElPos = vm.getPosition();
        var targetElPos = {};

        var targetElWidth = vm.size.width;
        var targetElHeight = vm.size.height;

        var shiftWidth = {
          center: widthCenter,
          left: widthLeft,
          right: widthRight
        };

        var shiftHeight = {
          center: heightCenter,
          top: heightTop,
          bottom: heightBottom
        };

        switch (pos0) {
          case 'right':
            targetElPos = {
              top: shiftHeight[pos1](),
              left: shiftWidth[pos0]()
            };
            break;
          case 'left':
            targetElPos = {
              top: shiftHeight[pos1](),
              left: hostElPos.left - targetElWidth
            };
            break;
          case 'bottom':
            targetElPos = {
              top: shiftHeight[pos0](),
              left: shiftWidth[pos1]()
            };
            break;
          default:
            targetElPos = {
              top: hostElPos.top - targetElHeight,
              left: shiftWidth[pos1]()
            };
            break;
        }

        return targetElPos;

        function widthRight() {
          return hostElPos.left + hostElPos.width;
        }

        function widthLeft() {
          return hostElPos.left;
        }

        function widthCenter() {
          return hostElPos.left + hostElPos.width / 2 - targetElWidth / 2;
        }

        function heightBottom() {
          return hostElPos.top + hostElPos.height;
        }

        function heightTop() {
          return hostElPos.top;
        }

        function heightCenter() {
          return hostElPos.top + hostElPos.height / 2 - targetElHeight / 2;
        }
      }
    }
  }
})();
