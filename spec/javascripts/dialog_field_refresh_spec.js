describe('dialogFieldRefresh', function() {
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
      autoRefreshOptions = 'autoRefreshOptions';

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
      expect(dialogFieldRefresh.triggerAutoRefresh).toHaveBeenCalledWith('autoRefreshOptions');
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
      spyOn(parent, 'postMessage');
    });

    context('when the trigger passed in falsy', function() {
      it('does not post any messages', function() {
        dialogFieldRefresh.triggerAutoRefresh({trigger: ""});
        expect(parent.postMessage).not.toHaveBeenCalled();
      });
    });

    context('when the trigger passed in is the string "true"', function() {
      context('when the next auto refreshable field does not exist', function() {
        beforeEach(function() {
          dialogFieldRefresh.triggerAutoRefresh({
            current_index: 0,
            auto_refreshable_field_indicies: [{tab_index: 1, group_index: 1, field_index: 1}],
            trigger: "true"
          });
        });

        it('does not post a message', function() {
          expect(parent.postMessage).not.toHaveBeenCalled();
        });
      });

      context('when the next auto refreshable field exists', function() {
        beforeEach(function() {
          dialogFieldRefresh.triggerAutoRefresh({
            current_index: 0,
            auto_refreshable_field_indicies: [
              {tab_index: 1, group_index: 1, field_index: 1},
              {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
            ],
            trigger: "true"
          });
        });

        it('posts a message', function() {
          expect(parent.postMessage).toHaveBeenCalledWith({tabIndex: 1, groupIndex: 1, fieldIndex: 2}, '*');
        });
      });
    });

    context('when the trigger passed in is true', function() {
      context('when the next auto refreshable field does not exist', function() {
        beforeEach(function() {
          dialogFieldRefresh.triggerAutoRefresh({
            current_index: 0,
            auto_refreshable_field_indicies: [{tab_index: 1, group_index: 1, field_index: 1}],
            trigger: true
          });
        });

        it('does not post a message', function() {
          expect(parent.postMessage).not.toHaveBeenCalled();
        });
      });

      context('when the next auto refreshable field exists', function() {
        beforeEach(function() {
          dialogFieldRefresh.triggerAutoRefresh({
            current_index: 0,
            auto_refreshable_field_indicies: [
              {tab_index: 1, group_index: 1, field_index: 1},
              {tab_index: 1, group_index: 1, field_index: 2, auto_refresh: true}
            ],
            trigger: true
          });
        });

        it('posts a message', function() {
          expect(parent.postMessage).toHaveBeenCalledWith({tabIndex: 1, groupIndex: 1, fieldIndex: 2}, '*');
        });
      });
    });
  });
});
