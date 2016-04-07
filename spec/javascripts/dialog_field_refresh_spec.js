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
        data = {values: {refreshed_values: [["test", "test"], ["not test", "not test"]], checked_value: null}};
      });

      it('selects the first option', function() {
        dialogFieldRefresh.addOptionsToDropDownList(data, 345);
        expect($('.dynamic-drop-down-345.selectpicker').val()).toBe('test');
      });
    });
  });

  describe('#refreshDropDownList', function() {
    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'addOptionsToDropDownList');

      spyOn($.fn, 'selectpicker');
      spyOn($, 'post').and.callFake(function() {
        var d = $.Deferred();
        d.resolve("the data");
        return d.promise();
      });
    });

    it('calls addOptionsToDropDownList', function() {
      dialogFieldRefresh.refreshDropDownList('abc', 123, 'test');
      expect(dialogFieldRefresh.addOptionsToDropDownList).toHaveBeenCalledWith("the data", 123);
    });

    it('ensures the select picker is refreshed', function() {
      dialogFieldRefresh.refreshDropDownList('abc', 123, 'test');
      expect($.fn.selectpicker).toHaveBeenCalledWith('refresh');
    });

    it('sets the value in the select picker', function() {
      dialogFieldRefresh.refreshDropDownList('abc', 123, 'test');
      expect($.fn.selectpicker).toHaveBeenCalledWith('val', 'test');
    });

    it('uses the correct selector', function() {
      dialogFieldRefresh.refreshDropDownList('abc', 123, 'test');
      expect($.fn.selectpicker.calls.mostRecent().object.selector).toEqual('#abc');
    });
  });
  
  describe('#initializeDialogSelectPicker', function() {
    var fieldName, selectedValue, url;

    beforeEach(function() {
      spyOn(dialogFieldRefresh, 'triggerAutoRefresh');
      spyOn(window, 'miqInitSelectPicker');
      spyOn(window, 'miqSelectPickerEvent');
      spyOn($.fn, 'selectpicker');
      fieldName = 'fieldName';
      fieldId = 'fieldId';
      selectedValue = 'selectedValue';
      url = 'url';

      var html = "";
      html += '<select id=fieldName class="dynamic-drop-down-193 selectpicker">';
      html += '<option value="1">1</option>';
      html += '<option value="2" selected="selected">2</option>';
      html += '</select>';

      setFixtures(html);
    });

    it('initializes the select picker', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url);
      expect(window.miqInitSelectPicker).toHaveBeenCalled();
    });

    it('sets the value of the select picker', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url);
      expect($.fn.selectpicker).toHaveBeenCalledWith('val', 'selectedValue');
    });

    it('uses the correct selector', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url);
      expect($.fn.selectpicker.calls.mostRecent().object.selector).toEqual('#fieldName');
    });

    it('sets up the select picker event', function() {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url);
      expect(window.miqSelectPickerEvent).toHaveBeenCalledWith('fieldName', 'url', {callback: jasmine.any(Function)});
    });

    it('triggers the auto refresh when the drop down changes', function(done) {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url);
      done();
      expect(dialogFieldRefresh.triggerAutoRefresh).toHaveBeenCalledWith(fieldId, 'true');
    });

    it('triggers autorefresh with "false" when triggerAutoRefresh arg is false', function(done) {
      dialogFieldRefresh.initializeDialogSelectPicker(fieldName, fieldId, selectedValue, url, 'false');
      done();
      expect(dialogFieldRefresh.triggerAutoRefresh).toHaveBeenCalledWith(fieldId, 'false');
    });
  });
});
