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
  function EditServiceModalController(serviceDetails, $state, $modalInstance, CollectionsApi, Notifications) {
    var vm = this;

    vm.service = serviceDetails;
    vm.saveServiceDetails = saveServiceDetails;

    vm.modalData = {
      'action': 'edit',
      'resource': {
        'name': vm.service.name || '',
        'description': vm.service.description || ''
      }
    };

    activate();

    function activate() {
    }

    function saveServiceDetails() {
      CollectionsApi.post('services', vm.service.id, {}, vm.modalData).then(saveSuccess, saveFailure);

      function saveSuccess() {
        $modalInstance.close();
        Notifications.success(vm.service.name + ' was edited.');
        $state.go($state.current, {}, {reload: true});
      }

      function saveFailure() {
        Notifications.error('There was an error editing this service.');
      }
    }
  }
})();
