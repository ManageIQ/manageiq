/* jshint -W117, -W030 */
describe('Marketplace.details', function() {
  beforeEach(function() {
    module('app.states', 'app.config', bard.fakeToastr);
  });

  describe('#resolveDialogs', function() {
    var collectionsApiSpy;

    beforeEach(function() {
      bard.inject('$state', '$stateParams', 'CollectionsApi');

      $stateParams.serviceTemplateId = 123;
      collectionsApiSpy = sinon.spy(CollectionsApi, 'query');
    });

    it('should query the API with the correct template id and options', function() {
      var options = {expand: 'resources', attributes: 'content'};
      $state.get('marketplace.details').resolve.dialogs($stateParams, CollectionsApi);
      expect(collectionsApiSpy).to.have.been.calledWith('service_templates/123/service_dialogs', options);
    });
  });

  describe('controller', function() {
    var collectionsApiSpy;
    var controller;
    var notificationsErrorSpy;
    var notificationsSuccessSpy;
    var dialogs = {
      subcount: 1,
      resources: [{
        content: [{
          dialog_tabs: [{
            dialog_groups: [{
              dialog_fields: [{
                name: 'dialogField1',
                default_value: '1'
              }, {
                name: 'dialogField2',
                default_value: '2'
              }]
            }]
          }]
        }]
      }]
    };

    var serviceTemplate = {id: 123, service_template_catalog_id: 321};

    var controllerResolves = {
      dialogs: dialogs,
      serviceTemplate: serviceTemplate
    };

    beforeEach(function() {
      bard.inject('$controller', '$log', '$state', '$rootScope', 'CollectionsApi', 'Notifications');

      controller = $controller($state.get('marketplace.details').controller, controllerResolves);
      $rootScope.$apply();
    });

    describe('controller initialization', function() {
      it('is created successfully', function() {
        expect(controller).to.be.defined;
      });
    });

    describe('controller#submitDialog', function() {
      describe('when the API call is successful', function() {
        beforeEach(function() {
          var successResponse = {
            message: 'Great Success!'
          };

          collectionsApiSpy = sinon.stub(CollectionsApi, 'post').returns(Promise.resolve(successResponse));
          notificationsSuccessSpy = sinon.spy(Notifications, 'success');
        });

        it('POSTs to the service templates API', function() {
          controller.submitDialog();
          expect(collectionsApiSpy).to.have.been.calledWith(
            'service_catalogs/321/service_templates',
            123,
            {},
            '{"action":"order","resource":{"href":"/api/service_templates/123","dialogField1":"1","dialogField2":"2"}}'
          );
        });

        it('makes a notification success call', function(done) {
          controller.submitDialog();
          done();
          expect(notificationsSuccessSpy).to.have.been.calledWith('Great Success!');
        });

        it('goes to the requests list', function(done) {
          controller.submitDialog();
          done();
          expect($state.is('requests.list')).to.be.true;
        });
      });

      describe('when the API call fails', function() {
        beforeEach(function() {
          var errorResponse = 'oopsies';

          collectionsApiSpy = sinon.stub(CollectionsApi, 'post').returns(Promise.reject(errorResponse));
          notificationsErrorSpy = sinon.spy(Notifications, 'error');
        });

        it('makes a notification error call', function(done) {
          controller.submitDialog();
          done();
          expect(notificationsErrorSpy).to.have.been.calledWith(
            'There was an error submitting this request: oopsies'
          );
        });
      });
    });
  });
});
