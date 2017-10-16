describe('dialogFieldRefresh', function() {
  describe('#listenForAutoRefreshMessages', function() {
    context('when an autoRefresh event gets triggered', function() {
      var callback;
      var autoRefreshOptions;

      beforeEach(function() {
        callback = jasmine.createSpyObj('callback', ['call']);
        autoRefreshOptions = {
          tab_index: 1,
          group_index: 2,
          field_index: 3
        };
        dialogFieldRefresh.listenForAutoRefreshMessages(autoRefreshOptions, callback);
      });

      context('when the tab index, group index, and field index match the corresponding field', function() {
        beforeEach(function() {
          $(document).trigger('dialog::autoRefresh', {tabIndex: 1, groupIndex: 2, fieldIndex: 3, initializingIndex: 6});
        });

        it('executes the callback', function() {
          expect(callback.call).toHaveBeenCalledWith(null, 6);
        });
      });

      context('when the tab index, group index, and field index do not match the corresponding field', function() {
        beforeEach(function() {
          $(document).trigger('dialog::autoRefresh', {tabIndex: 1, groupIndex: 1, fieldIndex: 3});
        });

        it('does not execute the callback', function() {
          expect(callback.call).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('#unbindAllPreviousListeners', function() {
    beforeEach(function() {
      spyOn($.fn, 'off');
    });

    it('unbinds all autoRefresh messages from the document', function() {
      dialogFieldRefresh.unbindAllPreviousListeners();
      expect($.fn.off.calls.mostRecent().object).toEqual(document);
      expect($.fn.off).toHaveBeenCalledWith('dialog::autoRefresh');
    });
  });

  describe('#addOptionsToDropDownList', function() {
    var data = {};

    beforeEach(function() {
      var html = "";
      html += '<select class="dynamic-drop-down-345 selectpicker">';
      html += '</select>';
      setFixtures(html);
    });

    context('when the refreshed values contain a checked value', function() {
      context('when the refreshed values contain a null key', function() {
        beforeEach(function() {
          data = {values: {refreshed_values: [[null, 'not test'], ['123', 'is test']], checked_value: 123}};
        });

        it('it does not blow up', function() {
          var test = function() {
            dialogFieldRefresh.addOptionsToDropDownList(data, 345);
          };
          expect(test).not.toThrow();
        });

        it('selects the option that corresponds to the checked value', function() {
          dialogFieldRefresh.addOptionsToDropDownList(data, 345);
          expect($('.dynamic-drop-down-345.selectpicker').val()).toBe('123');
        });
      });
    });

    context('when the refreshed values do not contain a checked value', function() {
      beforeEach(function() {
        data = {values: {refreshed_values: [["test", "test"], ["not test", "not test"]], checked_value: null, visible: false}};
      });

      it('selects the first option', function() {
        dialogFieldRefresh.addOptionsToDropDownList(data, 345);
        expect($('.dynamic-drop-down-345.selectpicker').val()).toBe('test');
      });
    });
  });

  describe('#setReadOnly', function() {
    beforeEach(function() {
      var html = "";
      html += '<input id="text-test" title="bogus title" type="text" />';
      setFixtures(html);
    });

    context('when readOnly is true', function() {
      it('sets the title', function() {
        dialogFieldRefresh.setReadOnly($('#text-test'), true);
        expect($('#text-test').attr('title')).toBe('This element is disabled because it is read only');
      });

      it('disables the element', function() {
        dialogFieldRefresh.setReadOnly($('#text-test'), true);
        expect($('#text-test').prop('disabled')).toBe(true);
      });
    });

    context('when readOnly is false', function() {
      it('clears the title', function() {
        dialogFieldRefresh.setReadOnly($('#text-test'), false);
        expect($('#text-test').attr('title')).toBe('');
      });

      it('enables the element', function() {
        dialogFieldRefresh.setReadOnly($('#text-test'), false);
        expect($('#text-test').prop('disabled')).toBe(false);
      });
    });
  });

  describe('#setVisible', function() {
    beforeEach(function() {
      var html = "";
      html += '<input id="text-test" title="bogus title" type="text" />';
      setFixtures(html);
    });

    context('when visible is true', function() {
      it('shows the element', function() {
        dialogFieldRefresh.setVisible($('#text-test'), true);
        expect($('#text-test').is(":visible")).toBe(true);
      });
    });

    context('when visible is false', function() {
      it('hides the element', function() {
        dialogFieldRefresh.setVisible($('#text-test'), false);
        expect($('#text-test').is(":visible")).toBe(false);
      });
    });
  });

  describe('#refreshField', function() {
    var options = {name: 'name', id: '123'};
    var callback = function() { return 'the callback'; };

    context('when the field type is DialogFieldCheckBox', function() {
      beforeEach(function() {
        options.type = 'DialogFieldCheckBox';
        spyOn(dialogFieldRefresh, 'refreshCheckbox');
      });

      it('calls refreshCheckbox', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshCheckbox).toHaveBeenCalledWith('name', '123', callback);
      });
    });

    context('when the field type is DialogFieldTextBox', function() {
      beforeEach(function() {
        options.type = 'DialogFieldTextBox';
        spyOn(dialogFieldRefresh, 'refreshTextBox');
      });

      it('calls refreshTextBox', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshTextBox).toHaveBeenCalledWith('name', '123', callback);
      });
    });

    context('when the field type is DialogFieldTextAreaBox', function() {
      beforeEach(function() {
        options.type = 'DialogFieldTextAreaBox';
        spyOn(dialogFieldRefresh, 'refreshTextAreaBox');
      });

      it('calls refreshTextAreaBox', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshTextAreaBox).toHaveBeenCalledWith('name', '123', callback);
      });
    });

    context('when the field type is DialogFieldDropDownList', function() {
      beforeEach(function() {
        var html = '';
        html += '<select name="name"><option selected="selected" value="1">One</option></select>';
        setFixtures(html);

        options.type = 'DialogFieldDropDownList';
        spyOn(dialogFieldRefresh, 'refreshDropDownList');
      });

      it('calls refreshDropDownList', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshDropDownList).toHaveBeenCalledWith('name', '123', '1', callback);
      });
    });

    context('when the field type is DialogFieldRadioButton', function() {
      beforeEach(function() {
        var html = '';
        html += '<input type="radio" name="name" value="1" checked /><input type="radio" name="name" value="2" />';
        setFixtures(html);

        options.type = 'DialogFieldRadioButton';
        options.url = 'url';
        options.auto_refresh_options = 'auto_refresh_options';
        spyOn(dialogFieldRefresh, 'refreshRadioList');
      });

      it('calls refreshRadioList', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshRadioList).toHaveBeenCalledWith(
          'name', '123', '1', 'url', 'auto_refresh_options', callback
        );
      });
    });

    context('when the field type is DialogFieldDateControl', function() {
      beforeEach(function() {
        options.type = 'DialogFieldDateControl';
        spyOn(dialogFieldRefresh, 'refreshDateTime');
      });

      it('calls refreshDateControl', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshDateTime).toHaveBeenCalledWith('name', '123', callback);
      });
    });

    context('when the field type is DialogFieldDateTimeControl', function() {
      beforeEach(function() {
        options.type = 'DialogFieldDateTimeControl';
        spyOn(dialogFieldRefresh, 'refreshDateTime');
      });

      it('calls refreshDateTimeControl', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(dialogFieldRefresh.refreshDateTime).toHaveBeenCalledWith('name', '123', callback);
      });
    });

    context('when the field type is not supported', function() {
      beforeEach(function() {
        options.type = 'wrong';
        spyOn(window, 'add_flash');
      });

      it('adds a flash message', function() {
        dialogFieldRefresh.refreshField(options, callback);
        expect(window.add_flash).toHaveBeenCalledWith(__("Field type is not a supported type!"), 'error');
      });
    });
  });

  describe('#refreshCheckbox', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'setReadOnly');
      spyOn(dialogFieldRefresh, 'setVisible');
      spyOn($.fn, 'prop');
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshCheckbox('abc', 123, refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_checkbox_refresh',
        {name: 'abc'},
        loadedDoneFunction
      );
    });

    describe('#refreshCheckbox doneFunction', function() {
      beforeEach(function() {
        dialogFieldRefresh.refreshCheckbox('abc', 123, refreshCallback);
        var data = {responseText: JSON.stringify({values: {checked: true, read_only: true, visible: false}})};
        loadedDoneFunction(data);
      });

      it('sets the checked prop to the checked value', function() {
        expect($.fn.prop).toHaveBeenCalledWith('checked', true);
      });

      it('uses the correct selector', function() {
        expect($.fn.prop.calls.mostRecent().object.selector).toEqual('.dynamic-checkbox-123');
      });

      it('sets the read only property', function() {
        expect(dialogFieldRefresh.setReadOnly).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '.dynamic-checkbox-123'}),
          true
        );
      });

      it('sets the visible property', function() {
        expect(dialogFieldRefresh.setVisible).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#field_123_tr'}),
          false
        );
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#refreshDateTime', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'setReadOnly');
      spyOn(dialogFieldRefresh, 'setVisible');
      spyOn($.fn, 'val');
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshDateTime('abc', 123, refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_date_refresh',
        {name: 'abc'},
        loadedDoneFunction
      );
    });

    describe('#refreshDateTime doneFunction', function() {
      beforeEach(function() {
        dialogFieldRefresh.refreshDateTime('abc', 123, refreshCallback);
        var data = {responseText: JSON.stringify({values: {date: 'today', hour: '12', min: '34', read_only: true, visible: false}})};
        loadedDoneFunction(data);
      });

      it('sets the date val to the response data date', function() {
        expect($.fn.val).toHaveBeenCalledWith('today');
      });

      it('uses the correct selector', function() {
        expect($.fn.val.calls.first().object.selector).toEqual('.dynamic-date-123');
      });

      it('sets the hours val to the response data hour', function() {
        expect($.fn.val).toHaveBeenCalledWith('12');
      });

      it('uses the correct selector', function() {
        expect($.fn.val.calls.all()[1].object.selector).toEqual('.dynamic-date-hour-123');
      });

      it('sets the mins val to the response data min', function() {
        expect($.fn.val).toHaveBeenCalledWith('34');
      });

      it('uses the correct selector', function() {
        expect($.fn.val.calls.mostRecent().object.selector).toEqual('.dynamic-date-min-123');
      });

      it('sets the read only property', function() {
        expect(dialogFieldRefresh.setReadOnly).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '.dynamic-date-123'}),
          true
        );
      });

      it('sets the visible property', function() {
        expect(dialogFieldRefresh.setVisible).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#field_123_tr'}),
          false
        );
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#refreshTextBox', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'setReadOnly');
      spyOn(dialogFieldRefresh, 'setVisible');
      spyOn($.fn, 'val');
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshTextBox('abc', 123, refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_text_box_refresh',
        {name: 'abc'},
        loadedDoneFunction
      );
    });

    describe('#refreshTextBox doneFunction', function() {
      beforeEach(function() {
        dialogFieldRefresh.refreshTextBox('abc', 123, refreshCallback);
        var data = {responseText: JSON.stringify({values: {text: 'text', read_only: true, visible: false}})};
        loadedDoneFunction(data);
      });

      it('sets the value of the text box with the text data', function() {
        expect($.fn.val).toHaveBeenCalledWith('text');
      });

      it('uses the correct selector', function() {
        expect($.fn.val.calls.mostRecent().object.selector).toEqual('.dynamic-text-box-123');
      });

      it('sets the read only property', function() {
        expect(dialogFieldRefresh.setReadOnly).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '.dynamic-text-box-123'}),
          true
        );
      });

      it('sets the visible property', function() {
        expect(dialogFieldRefresh.setVisible).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#field_123_tr'}),
          false
        );
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#refreshTextAreaBox', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'setReadOnly');
      spyOn(dialogFieldRefresh, 'setVisible');
      spyOn($.fn, 'val');
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshTextAreaBox('abc', 123, refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_text_box_refresh',
        {name: 'abc'},
        loadedDoneFunction
      );
    });

    describe('#refreshTextAreaBox doneFunction', function() {
      beforeEach(function() {
        dialogFieldRefresh.refreshTextAreaBox('abc', 123, refreshCallback);
        var data = {responseText: JSON.stringify({values: {text: 'text', read_only: true, visible: false}})};
        loadedDoneFunction(data);
      });

      it('sets the value of the text box with the text data', function() {
        expect($.fn.val).toHaveBeenCalledWith('text');
      });

      it('uses the correct selector', function() {
        expect($.fn.val.calls.mostRecent().object.selector).toEqual('.dynamic-text-area-123');
      });

      it('sets the read only property', function() {
        expect(dialogFieldRefresh.setReadOnly).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '.dynamic-text-area-123'}),
          true
        );
      });

      it('sets the visible property', function() {
        expect(dialogFieldRefresh.setVisible).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#field_123_tr'}),
          false
        );
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#refreshDropDownList', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'addOptionsToDropDownList');
      spyOn(dialogFieldRefresh, 'setReadOnly');
      spyOn(dialogFieldRefresh, 'setVisible');
      spyOn($.fn, 'selectpicker');
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshDropDownList('abc', 123, 'test', refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_radio_button_refresh',
        {name: 'abc', checked_value: 'test'},
        loadedDoneFunction
      );
    });

    describe('#refreshDropDownList doneFunction', function() {
      beforeEach(function() {
        dialogFieldRefresh.refreshDropDownList('abc', 123, 'test', refreshCallback);
        var data = {responseText: JSON.stringify({values: {checked_value: 'selectedTest', read_only: true, visible: false}})};
        loadedDoneFunction(data);
      });

      it('adds the options to the dropdown list', function() {
        expect(dialogFieldRefresh.addOptionsToDropDownList).toHaveBeenCalledWith(
          {values: {checked_value: 'selectedTest', read_only: true, visible: false}},
          123
        );
      });

      it('sets the read only property', function() {
        expect(dialogFieldRefresh.setReadOnly).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#abc'}),
          true
        );
      });

      it('sets the visible property', function() {
        expect(dialogFieldRefresh.setVisible).toHaveBeenCalledWith(
          jasmine.objectContaining({selector: '#field_' + 123 + "_tr"}),
          false
        );
      });

      it('ensures the select picker is refreshed', function() {
        expect($.fn.selectpicker).toHaveBeenCalledWith('refresh');
      });

      it('sets the value in the select picker', function() {
        expect($.fn.selectpicker).toHaveBeenCalledWith('val', 'selectedTest');
      });

      it('uses the correct selector', function() {
        expect($.fn.selectpicker.calls.mostRecent().object.selector).toEqual('#abc');
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#refreshRadioList', function() {
    var loadedDoneFunction;
    var refreshCallback;

    beforeEach(function() {
      refreshCallback = jasmine.createSpyObj('refreshCallback', ['call']);

      spyOn(dialogFieldRefresh, 'sendRefreshRequest').and.callFake(function(_url, _data, doneFunction) {
        loadedDoneFunction = doneFunction;
      });
      spyOn(dialogFieldRefresh, 'replaceRadioButtons');
    });

    it('calls sendRefreshRequest', function() {
      dialogFieldRefresh.refreshRadioList('abc', 123, 'test', 'url', 'autoRefreshOptions', refreshCallback);
      expect(dialogFieldRefresh.sendRefreshRequest).toHaveBeenCalledWith(
        'dynamic_radio_button_refresh',
        {name: 'abc', checked_value: 'test'},
        loadedDoneFunction
      );
    });

    describe('#refreshDropDownList doneFunction', function() {
      var data;

      beforeEach(function() {
        dialogFieldRefresh.refreshRadioList('abc', 123, 'test', 'url', 'autoRefreshOptions', refreshCallback);
        data = {
          responseText: JSON.stringify({
            read_only: true,
            visible: false,
            values: {
              checked_value: 'selectedTest',
              refreshed_values: [['1', 'first'], ['2', 'second']]
            }
          })
        };
        loadedDoneFunction(data);
      });

      it('replaces the radio buttons', function() {
        expect(dialogFieldRefresh.replaceRadioButtons).toHaveBeenCalledWith(
          123,
          'abc',
          JSON.parse(data.responseText),
          'url',
          'autoRefreshOptions'
        );
      });

      it('calls the callback', function() {
        expect(refreshCallback.call).toHaveBeenCalled();
      });
    });
  });

  describe('#initializeDialogSelectPicker', function() {
    var fieldName, selectedValue, url, autoRefreshOptions;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'triggerAutoRefresh');
      spyOn(window, 'miqInitSelectPicker');
      spyOn(window, 'miqSelectPickerEvent').and.callFake(function(fieldName, url, options) {
        options.callback();
      });
      spyOn($.fn, 'selectpicker');
      fieldName = 'fieldName';
      selectedValue = 'selectedValue';
      url = 'url';
      autoRefreshOptions = {pretend: 'options'};

      var html = "";
      html += '<select id=fieldName class="dynamic-drop-down-193 selectpicker">';
      html += '<option value="1">1</option>';
      html += '<option value="2" selected="selected">2</option>';
      html += '</select>';

      setFixtures(html);
    });

    it('initializes the select picker', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, selectedValue, url, autoRefreshOptions);
      expect(window.miqInitSelectPicker).toHaveBeenCalled();
    });

    it('sets the value of the select picker', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, selectedValue, url, autoRefreshOptions);
      expect($.fn.selectpicker).toHaveBeenCalledWith('val', 'selectedValue');
    });

    it('uses the correct selector', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, selectedValue, url, autoRefreshOptions);
      expect($.fn.selectpicker.calls.mostRecent().object.selector).toEqual('#fieldName');
    });

    it('sets up the select picker event', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, selectedValue, url, autoRefreshOptions);
      expect(window.miqSelectPickerEvent).toHaveBeenCalledWith('fieldName', 'url', {callback: jasmine.any(Function)});
    });

    it('triggers autorefresh with true only when triggerAutoRefresh arg is true', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, selectedValue, url, autoRefreshOptions);
      expect(dialogFieldRefresh.triggerAutoRefresh).toHaveBeenCalledWith({pretend: 'options', initial_trigger: true});
    });
  });

  describe('#initializeRadioButtonOnClick', function() {
    var loadedSelectCallback;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'radioButtonSelectEvent').and.callFake(function(_url, _fieldId, selectCallback) {
        loadedSelectCallback = selectCallback;
      });
      spyOn(dialogFieldRefresh, 'triggerAutoRefresh');

      var html = '<div id="dynamic-radio-123">';
      html += '<input id="clickMe"/>';
      html += '</div>';
      setFixtures(html);
    });

    it('sets up the radio button select event for clicks', function() {
      dialogFieldRefresh.initializeRadioButtonOnClick(123, 'url', 'autoRefreshOptions');
      $('#clickMe').trigger('click');
      expect(dialogFieldRefresh.radioButtonSelectEvent).toHaveBeenCalledWith('url', 123, loadedSelectCallback);
    });

    describe('#initializeRadioButtonOnClick select event callback', function() {
      beforeEach(function() {
        dialogFieldRefresh.initializeRadioButtonOnClick(123, 'url', 'autoRefreshOptions');
        $('#clickMe').trigger('click');
      });

      it('triggers an auto refresh', function() {
        loadedSelectCallback();
        expect(dialogFieldRefresh.triggerAutoRefresh).toHaveBeenCalledWith('autoRefreshOptions');
      });
    });
  });

  describe('#radioButtonSelectEvent', function() {
    beforeEach(function() {
      spyOn(window, 'miqObserveRequest');
      var html = '<form id="dynamic-radio-123">';
      html += '<input type="text" name="textbox" value="test" />';
      html += '</form>';
      setFixtures(html);
    });

    it('makes an miqObserveRequest', function() {
      dialogFieldRefresh.radioButtonSelectEvent('url', 123, 'callback');
      expect(window.miqObserveRequest).toHaveBeenCalledWith('url', {
        data: 'textbox=test',
        dataType: 'script',
        beforeSend: true,
        complete: true,
        done: 'callback'
      });
    });
  });

  describe('#triggerAutoRefresh', function() {
    beforeEach(function() {
      spyOn($.fn, 'trigger');
    });

    context('when the trigger passed in falsy', function() {
      it('does not post any messages', function() {
        dialogFieldRefresh.triggerAutoRefresh({trigger: ""});
        expect($.fn.trigger).not.toHaveBeenCalled();
      });
    });

    context('when the trigger passed in is the string "true"', function() {
      context('when we are triggering for the initial trigger', function() {
        context('when there are auto refreshable fields other than ourselves', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 2,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true},
                {tab_index: 1, group_index: 1, field_index: 3, auto_refresh: true}
              ],
              trigger: "true",
              initial_trigger: true
            });
          });

          it('triggers a refresh on the first available auto refreshable element', function() {
            expect($.fn.trigger).toHaveBeenCalledWith('dialog::autoRefresh', {
              tabIndex: 1, groupIndex: 1, fieldIndex: 2, initializingIndex: 2
            });
          });
        });

        context('when there are not auto refreshable fields other than ourselves', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 1,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
              ],
              trigger: "true",
              initial_trigger: true
            });
          });

          it('does not trigger anything', function() {
            expect($.fn.trigger).not.toHaveBeenCalled();
          });
        });
      });

      context('when it is not the initial trigger', function() {
        context('when fields are available other than the field that initialized the triggering process', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 1,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true},
                {tab_index: 1, group_index: 1, field_index: 3},
                {tab_index: 1, group_index: 1, field_index: 4, auto_refresh: true}
              ],
              trigger: "true",
              initializingIndex: 0
            });
          });

          it('triggers a refresh on the next available auto refreshable element', function() {
            expect($.fn.trigger).toHaveBeenCalledWith('dialog::autoRefresh', {
              tabIndex: 1, groupIndex: 1, fieldIndex: 4, initializingIndex: 0
            });
          });
        });

        context('when there are no fields available other than the field that initialized the triggering process', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 0,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
              ],
              trigger: "true",
              initializingIndex: 1
            });
          });

          it('does not trigger anything', function() {
            expect($.fn.trigger).not.toHaveBeenCalled();
          });
        });
      });
    });

    context('when the trigger passed in is true', function() {
      context('when we are triggering for the initial trigger', function() {
        context('when there are auto refreshable fields other than ourselves', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 2,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true},
                {tab_index: 1, group_index: 1, field_index: 3, auto_refresh: true}
              ],
              trigger: true,
              initial_trigger: true
            });
          });

          it('triggers a refresh on the first available auto refreshable element', function() {
            expect($.fn.trigger).toHaveBeenCalledWith('dialog::autoRefresh', {
              tabIndex: 1, groupIndex: 1, fieldIndex: 2, initializingIndex: 2
            });
          });
        });

        context('when there are not auto refreshable fields other than ourselves', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 1,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
              ],
              trigger: true,
              initial_trigger: true
            });
          });

          it('does not trigger anything', function() {
            expect($.fn.trigger).not.toHaveBeenCalled();
          });
        });
      });

      context('when it is not the initial trigger', function() {
        context('when fields are available other than the field that initialized the triggering process', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 1,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true},
                {tab_index: 1, group_index: 1, field_index: 3},
                {tab_index: 1, group_index: 1, field_index: 4, auto_refresh: true}
              ],
              trigger: true,
              initializingIndex: 0
            });
          });

          it('triggers a refresh on the next available auto refreshable element', function() {
            expect($.fn.trigger).toHaveBeenCalledWith('dialog::autoRefresh', {
              tabIndex: 1, groupIndex: 1, fieldIndex: 4, initializingIndex: 0
            });
          });
        });

        context('when there are no fields available other than the field that initialized the triggering process', function() {
          beforeEach(function() {
            dialogFieldRefresh.triggerAutoRefresh({
              current_index: 0,
              auto_refreshable_field_indicies: [
                {tab_index: 1, group_index: 1, field_index: 1},
                {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
              ],
              trigger: true,
              initializingIndex: 1
            });
          });

          it('does not trigger anything', function() {
            expect($.fn.trigger).not.toHaveBeenCalled();
          });
        });
      });
    });
  });

  describe('#sendRefreshRequest', function() {
    beforeEach(function() {
      spyOn(window, 'miqObserveRequest');
    });

    it('delegates to miqObserveRequest', function() {
      dialogFieldRefresh.sendRefreshRequest('the url', 'the data', 'the done function');
      expect(window.miqObserveRequest).toHaveBeenCalledWith('the url', {
        data: 'the data',
        dataType: 'json',
        beforeSend: true,
        complete: true,
        done: 'the done function'
      });
    });
  });
});
