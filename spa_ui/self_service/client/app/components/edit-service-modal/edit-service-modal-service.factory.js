(function() {
  'use strict';

  angular.module('app.components')
    .factory('EditServiceModal', EditServiceFactory);

  /** @ngInject */
  function EditServiceFactory($modal) {
    var modalService = {
      showModal: showModal
    };

    return modalService;

    function showModal(serviceDetails) {
      var modalOptions = {
        templateUrl: 'app/components/edit-service-modal/edit-service-modal.html',
        controller: EditServiceModalController,
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
  function EditServiceModalController(serviceDetails, $state, $modalInstance, CollectionsApi) {
    var vm = this;

    vm.service = serviceDetails;
    vm.saveServiceDetails = saveServiceDetails;

    activate();

    function activate() {
    }

    function saveServiceDetails() {
      var data = {
        'action': 'edit',
        'resource': {
          'name': vm.service.name,
          'description': vm.service.description
        }
      };

      CollectionsApi.post('services', vm.service.id, {}, data).then(saveSuccess, saveFailure);

      function saveSuccess() {
        $modalInstance.close();
        $state.go('services.details', {serviceId: vm.service.id});
      }

      function saveFailure() {
      }
    }
  }
})();

/** @ngInject */
function resolveService($stateParams, CollectionsApi) {
  return CollectionsApi.get('services', $stateParams.serviceId);
}
