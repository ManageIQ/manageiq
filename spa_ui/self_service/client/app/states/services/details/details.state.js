(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'services.details': {
        url: '/:serviceId',
        templateUrl: 'app/states/services/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Details',
        resolve: {
          service: resolveService
        }
      }
    };
  }

  /** @ngInject */
  function resolveService($stateParams, CollectionsApi) {
    var options = {attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.get('services', $stateParams.serviceId, options);
  }

  /** @ngInject */
  function StateController($state, service, CollectionsApi, EditServiceModal, RetireServiceModal) {
    var vm = this;

    vm.title = 'Service Details';
    vm.service = service;

    vm.activate = activate;
    vm.removeService = removeService;
    vm.editServiceModal = editServieModal;
    vm.retireServiceNow = retireServiceNow;
    vm.retireServiceLater = retireServiceLater;

    activate();

    function activate() {
    }

    function removeService() {
      var removeAction = {'action': 'retire'};
      CollectionsApi.post('services', vm.service.id, {}, removeAction).then(removeSuccess, removeFailure);

      function removeSuccess() {
        $state.go('services.list');
      }

      function removeFailure(data) {
      }
    }

    function editServieModal() {
      EditServiceModal.showModal(vm.service);
    }

    function retireServiceNow(){
      var data = {"action" : "retire"};
      CollectionsApi.post('services', vm.service.id, {}, data).then(retireSuccess, retireFailure);

      function retireSuccess(){
        $state.go('services.list');
      }

      function retireFailure(){

      }
    }

    function retireServiceLater(){
      RetireServiceModal.showModal(vm.service);
    }
  }
})();
