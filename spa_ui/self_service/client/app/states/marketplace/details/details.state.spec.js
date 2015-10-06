/* jshint -W117, -W030 */
describe('Marketplace.details', function() {
  beforeEach(function() {
    module('app.states', 'app.config', bard.fakeToastr);
  });

  describe('#resolveDialogs', function() {
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
});
