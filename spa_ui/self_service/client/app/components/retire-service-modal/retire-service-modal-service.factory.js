(function() {
  'use strict';

  angular.module('app.components')
    .factory('RetireServiceModal', RetireServiceFactory);

  /** @ngInject */
  function RetireServiceFactory($modal) {
    var modalService = {
      showModal: showModal
    };

    return modalService;

    function showModal(serviceDetails) {
      var modalOptions = {
        templateUrl: 'app/components/retire-service-modal/retire-service-modal.html',
        controller: RetireServiceModalController,
        controllerAs: 'vm',
        size: 'lg',
        resolve: {
          serviceDetails: resolveServiceDetails
        }
      };
      var modal = $modal.open(modalOptions);

      return modal.result;

      function resolveServiceDetails() {
        return serviceDetails;
      }
    }
  }

  /** @ngInject */
  function RetireServiceModalController(serviceDetails, $state, $modalInstance, CollectionsApi, Notifications) {
    var vm = this;

    vm.service = serviceDetails;
    vm.retireService = retireService;
    var existingDate = new Date(vm.service.retires_on);
    var existingUTCDate = new Date(existingDate.getTime() + existingDate.getTimezoneOffset() * 60000);
    vm.modalData = {
      action: 'retire',
      resource: {
        date: vm.service.retires_on ? existingUTCDate : new Date(),
        warn: vm.service.retirement_warn || 0
      }
    };

    vm.dateOptions = {
      autoclose: true,
      todayBtn: 'linked',
      todayHighlight: true
    };

    activate();

    function activate() {
    }

    function retireService() {
      CollectionsApi.post('services', vm.service.id, {}, vm.modalData).then(retireSuccess, retireFailure);

      function retireSuccess() {
        $modalInstance.close();
        Notifications.success('Scheduling retirement for' + vm.service.name  + '.');
        $state.go($state.current, {}, {reload: true});
      }

      function retireFailure() {
        Notifications.error('There was an error retiring this service.');
      }
    }
  }
})();
