/* jshint -W117, -W030 */
describe('app.services.DialogFieldRefresh', function() {
  beforeEach(function() {
    module('app.states', 'app.config', 'app.services', bard.fakeToastr);
    bard.inject('CollectionsApi', 'Notifications', 'DialogFieldRefresh');
  });

  describe('#listenForAutoRefreshMessages', function() {
    var eventListenerSpy;

    beforeEach(function() {
      eventListenerSpy = sinon.spy(window, 'addEventListener');
    });

    afterEach(function() {
      window.addEventListener.restore();
    });

    it('sets up a listener on the window', function() {
      DialogFieldRefresh.listenForAutoRefreshMessages([], [], 'the_url', '123');
      expect(eventListenerSpy).to.have.been.calledWith('message');
    });
  });

  describe('#refreshSingleDialogField with values not as an object', function() {
    var dialog1 = {name: 'dialog1', default_value: 'name1'};
    var dialog2 = {name: 'dialog2', default_value: 'name2'};
    var allDialogFields = [dialog1, dialog2];
    var collectionsApiSpy;
    var triggerAutoRefreshSpy;

    describe('when the API call is successful', function() {
      var successResponse;

      beforeEach(function() {
        successResponse = {
          result: {
            dialog1: {
              data_type: 'string',
              options: 'options',
              read_only: false,
              required: false,
              values: 'Text'
            }
          }
        };

        triggerAutoRefreshSpy = sinon.stub(DialogFieldRefresh, 'triggerAutoRefresh');
        collectionsApiSpy = sinon.stub(CollectionsApi, 'post').returns(Promise.resolve(successResponse));
      });

      it('updates the attributes for the dialog field', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(dialog1.data_type).to.eq('string');
        expect(dialog1.options).to.eq('options');
        expect(dialog1.read_only).to.be.false;
        expect(dialog1.required).to.be.false;
        expect(dialog1.default_value).to.eq('Text');
      });

      it('triggers an auto-refresh', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(triggerAutoRefreshSpy).to.have.been.called;
      });
    });
  });

  describe('#refreshSingleDialogField with values as an object', function() {
    var dialog1 = {name: 'dialog1', default_value: 'name1'};
    var dialog2 = {name: 'dialog2', default_value: 'name2'};
    var allDialogFields = [dialog1, dialog2];
    var collectionsApiSpy;
    var triggerAutoRefreshSpy;

    describe('when the API call is successful', function() {
      var successResponse;

      beforeEach(function() {
        successResponse = {
          result: {
            dialog1: {
              default_value: 'new default value',
              data_type: 'string',
              options: 'options',
              read_only: false,
              required: false,
              values: [['1', 'One'], ['2', 'Two']]
            }
          }
        };

        triggerAutoRefreshSpy = sinon.stub(DialogFieldRefresh, 'triggerAutoRefresh');
        collectionsApiSpy = sinon.stub(CollectionsApi, 'post').returns(Promise.resolve(successResponse));
      });

      it('calls the API with the correct parameters', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(collectionsApiSpy).to.have.been.calledWith(
          'the_url',
          123,
          {},
          JSON.stringify({
            action: 'refresh_dialog_fields',
            resource: {
              dialog_fields: {dialog1: 'name1', dialog2: 'name2'},
              fields: ['dialog1']
            }
          })
        );
      });

      it('updates the attributes for the dialog field', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(dialog1.data_type).to.eq('string');
        expect(dialog1.options).to.eq('options');
        expect(dialog1.read_only).to.be.false;
        expect(dialog1.required).to.be.false;
        var dialog1Values = JSON.stringify(dialog1.values);
        var dialog1ExpectedValues = JSON.stringify([['1', 'One'], ['2', 'Two']]);
        expect(dialog1Values).to.eq(dialog1ExpectedValues);
        expect(dialog1.default_value).to.eq('new default value');
      });

      it('triggers an auto-refresh', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(triggerAutoRefreshSpy).to.have.been.called;
      });
    });

    describe('when the API call fails', function() {
      var notificationsErrorSpy;

      beforeEach(function() {
        var errorResponse = 'oopsies';

        notificationsErrorSpy = sinon.spy(Notifications, 'error');
        collectionsApiSpy = sinon.stub(CollectionsApi, 'post').returns(Promise.reject(errorResponse));
      });

      it('returns a notification error', function(done) {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialog1, 'the_url', 123);
        done();
        expect(notificationsErrorSpy).to.have.been.calledWith('There was an error refreshing this dialog: oopsies');
      });
    });
  });

  describe('#triggerAutoRefresh', function() {
    var postMessageSpy;
    var dialogField = {};

    beforeEach(function() {
      postMessageSpy = sinon.stub(parent, 'postMessage');
      dialogField.name = 'dialogName';
    });

    afterEach(function() {
      parent.postMessage.restore();
    });

    describe('when the dialog field triggers auto refreshes', function() {
      beforeEach(function() {
        dialogField.trigger_auto_refresh = true;
      });

      it('posts a message with the field name', function() {
        DialogFieldRefresh.triggerAutoRefresh(dialogField);
        expect(postMessageSpy).to.have.been.calledWith({fieldName: 'dialogName'}, '*');
      });
    });

    describe('when the dialog field does not trigger auto refreshes', function() {
      beforeEach(function() {
        dialogField.trigger_auto_refresh = false;
      });

      it('does not post a message', function() {
        DialogFieldRefresh.triggerAutoRefresh(dialogField);
        expect(postMessageSpy).not.to.have.been.called;
      });
    });
  });
});

