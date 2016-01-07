describe('miq_application.js', function() {
  describe('miqSerializeForm', function () {
    beforeEach(function () {
      var html = '<div id="form_div"><textarea name="method_data">new line added\r\n\r\n</textarea></div>'
      setFixtures(html);
    });

    it('verify serialize method doesnt convert line feed value to windows line feed', function() {
      expect(miqSerializeForm('form_div')).toEqual("method_data=new+line+added%0A%0A");
    });
  });

  describe('miqInitToolbars', function () {
    beforeEach(function () {
      var html  = '<div id="toolbar"><div class="btn-group"><button class="btn btn-default" id="first">Click me!</button></div><div class="btn-group"><button class="btn btn-default dropdown-toggle" id="second">Click me!</button><ul class="dropdown-menu"><li><a href="#" id="third">Click me!</a></li></ul></div></div>';
      setFixtures(html);
    });

    it('initializes the onclick event on a regular toolbar button', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#first').click();
      expect(miqToolbarOnClick).toHaveBeenCalled();
    });

    it('not initializes an onclick event on a dropdown toolbar button', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#second').click();
      expect(miqToolbarOnClick).not.toHaveBeenCalled();
    });

    it('initializes the onclick event on a dropdown toolbar link', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#third').click();
      expect(miqToolbarOnClick).toHaveBeenCalled();
    });
  });

  describe('miqButtonOnWhen', function () {
    beforeEach(function () {
      var html = '<button id="button">Click me!</button>';
      setFixtures(html);
    });

    describe('nothing selected', function () {
      $.each(['1', '1+', '2+'], function (k, v) {
        it('disables the button when onwhen is ' + v, function () {
          var button = $('#button');
          miqButtonOnWhen(button, v, 0);
          expect(button.hasClass('disabled')).toBe(true);
        });
      });
    });

    describe('one selected', function () {
      $.each(['1', '1+'], function (k, v) {
        it('enables the button when onwhen is ' + v, function () {
          var button = $('#button');
          miqButtonOnWhen(button, v, 1);
          expect(button.hasClass('disabled')).toBe(false);
        });
      });

      it('disables the button when onwhen is 2+', function () {
          var button = $('#button');
          miqButtonOnWhen(button, '2+', 1);
          expect(button.hasClass('disabled')).toBe(true);
      });
    });

    describe('two selected', function () {
      $.each(['1+', '2+'], function (k, v) {
        it('enables the button when onwhen is ' + v, function () {
          var button = $('#button');
          miqButtonOnWhen(button, v, 2);
          expect(button.hasClass('disabled')).toBe(false);
        });
      });

      it('disables the button when onwhen is 1', function () {
          var button = $('#button');
          miqButtonOnWhen(button, '1', 2);
          expect(button.hasClass('disabled')).toBe(true);
      });
    });

    describe('three selected', function () {
      $.each(['1+', '2+'], function (k, v) {
        it('enables the button when onwhen is ' + v, function () {
          var button = $('#button');
          miqButtonOnWhen(button, v, 3);
          expect(button.hasClass('disabled')).toBe(false);
        });
      });

      it('disables the button when onwhen is 1', function () {
          var button = $('#button');
          miqButtonOnWhen(button, '1', 3);
          expect(button.hasClass('disabled')).toBe(true);
      });
    })
  });

  describe('miqShowAE_Tree', function () {
    it('uses url with the current controller', function() {
      ManageIQ.controller = 'catalog';
      spyOn(window, 'miqJqueryRequest');
      ae_url = "/" + ManageIQ.controller + "/ae_tree_select_toggle";
      miqShowAE_Tree('field_entry_point');
      expect(miqJqueryRequest).toHaveBeenCalledWith('/catalog/ae_tree_select_toggle?typ=field_entry_point');
    });
  });

});
