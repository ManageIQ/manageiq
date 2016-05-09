(function() {
  var EmsKeypairController = function($scope) {
    var vm = this;
    $scope.$on('resetClicked', function() {
      vm.resetClicked();
    });

    $scope.$on('setNewRecord', function(event, args) {
      if(args != undefined) {
        vm.newRecord = args.newRecord;
      }
      else {
        vm.newRecord = true;
      }
    });

    $scope.$on('setUserId', function(event, args) {
      if(args != undefined) {
        $scope.modelCopy[args.userIdName] = args.userIdValue;
      }
    });
  };

  EmsKeypairController.prototype.initialize = function(model, formId) {
    var vm = this;
    vm.model = model;
    vm.modelCopy = angular.copy(model);
    vm.formId = formId;
    vm.changeKey = undefined;

    if (vm.formId == 'new') {
      vm.newRecord = true;
    } else {
      vm.newRecord = false;
      vm.changeKey = false;
    }
  };

  EmsKeypairController.prototype.changeStoredPrivateKey = function() {
    this.changeKey = true;
    this.model.ssh_keypair_password = '';
  };

  EmsKeypairController.prototype.cancelPrivateKeyChange = function() {
    if (this.changeKey) {
      this.changeKey = false;
      this.model.ssh_keypair_password = '●●●●●●●●';
    }
  };

  EmsKeypairController.prototype.inEditMode = function(userid) {
    return (this.newRecord
            || !this.showChangePrivateKeyLinks(userid)
            || this.changeKey);
  };

  EmsKeypairController.prototype.showChangePrivateKeyLinks = function(userid) {
    return !this.newRecord && this.modelCopy[userid] != '';
  };

  EmsKeypairController.prototype.resetClicked = function() {
    this.newRecord = false;
    this.cancelPrivateKeyChange();
  };

  EmsKeypairController.prototype.showValidate = function(tab) {
    return !(this.model.emstype == 'openstack_infra' && this.newRecord && tab == 'ssh_keypair')
  };

  EmsKeypairController.$inject = ["$scope"];
  ManageIQ.angular.app.controller('emsKeypairController', EmsKeypairController);
})();
