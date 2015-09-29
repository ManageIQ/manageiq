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
  function RetireServiceModalController(serviceDetails, $state, $modalInstance, CollectionsApi) {
    var vm = this;

    vm.service = serviceDetails;
    vm.retireService = retireService;

    vm.modalData = {
      action: 'retire',
      resource: {date: vm.service.retires_on || new Date(), warn: vm.service.retirement_warn || 0}
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
        $state.go($state.current, {}, {reload: true});
      }

      function retireFailure() {
      }
    }
  }
})();
