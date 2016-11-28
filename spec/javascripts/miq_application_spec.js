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

  describe('miqToolbarOnClick', function () {
    beforeEach(function () {
      var html  = '<div id="toolbar"><div class="btn-group"><button class="btn btn-default dropdown-toggle" id="second">Click me!</button><ul class="dropdown-menu"><li><a id="reportButton" data-explorer="true" data-url_parms="?render_type=pdf" title="Download this report in PDF format" data-click="download_choice__render_report_pdf" name="download_choice__render_report_pdf" href="#"><i class="fa fa-file-text-o fa-lg" style="margin-right: 5px;"></i>Download as PDF</a></li><li><a id="notAReportButton" data-url="x_history?item=1" title="Go to this item" data-click="history_choice__history_1" name="history_choice__history_1" href="#"><i class="fa fa-arrow-left fa-lg" style="margin-right: 5px;"></i>All Saved Reports</a></li>';
      setFixtures(html);
    });

    it('leaves miqSparkle on for Report download buttons', function () {
      spyOn(window, "miqJqueryRequest");
      miqInitToolbars();
      $('#reportButton').click();
      expect(miqJqueryRequest).toHaveBeenCalledWith('/null/x_button?pressed=render_report_pdf', { beforeSend:true,
        complete: false,
        data: 'render_type=pdf' });
    });

    it('turns miqSparkle off for non-Report buttons', function () {
      spyOn(window, "miqJqueryRequest");
      miqInitToolbars();
      $('#notAReportButton').click();
      expect(miqJqueryRequest).toHaveBeenCalledWith('/null/x_history?item=1', { beforeSend:true, complete: true, data: undefined });
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

  describe('add_flash', function () {
    beforeEach(function () {
      var html = '<div id="flash_msg_div"></div>';
      setFixtures(html);
    });

    it('creates a flash message', function () {
      add_flash("foo", 'error');

      var text = $('#flash_msg_div strong').text();
      var klass = $('#flash_msg_div .alert').is('.alert-danger');
      var count = $('#flash_msg_div > *').length;
      expect(text).toEqual('foo');
      expect(klass).toEqual(true);
      expect(count).toEqual(1);
    });

    it('creates two flash messages', function () {
      add_flash("bar", 'info');
      add_flash("baz", 'success');

      var count = $('#flash_msg_div > *').length;
      expect(count).toEqual(2);
    });

    it('creates a unique flash message with id', function () {
      add_flash("bar", 'info', { id: "unique" });
      add_flash("baz", 'success', { id: "unique" });

      var text = $('#flash_msg_div strong').text();
      var klass = $('#flash_msg_div .alert').is('.alert-success');
      var count = $('#flash_msg_div > *').length;
      expect(text).toEqual('baz');
      expect(klass).toEqual(true);
      expect(count).toEqual(1);
    });
  });

  describe('miqUpdateElementsId', function () {
    beforeEach(function () {
      var html = '<div class="col-md-4 ui-sortable" id="col1"><div id="t_0|10000000000764" title="Drag this Tab to a new location"></div><div id="t_3|" title="Drag this Tab to a new location" class=""></div><div id="t_1|10000000000765" title="Drag this Tab to a new location"></div><div id="t_2|10000000000766" title="Drag this Tab to a new location"></div></div>'
      setFixtures(html);
    });

    it('updates element Id with new order', function () {
      ManageIQ.widget.dashboardUrl = 'dialog_res_reorder';
      miqUpdateElementsId($('.col-md-4'));
      var str = $('.col-md-4 > *').map(function(i, e) {
        return e.id;
      }).toArray().join(" ");
      expect(str).toEqual("t_0|10000000000764 t_1| t_2|10000000000765 t_3|10000000000766")
    });
  });

  describe('miqSendOneTrans', function () {
    beforeEach(function() {
      ManageIQ.oneTransition.oneTrans = undefined;
      ManageIQ.oneTransition.IEButtonPressed = false;

      spyOn(window, 'miqObserveRequest');
      spyOn(window, 'miqJqueryRequest');
    });

    it('calls miqJqueryRequest when given only url', function() {
      miqSendOneTrans('/foo');
      expect(miqJqueryRequest).toHaveBeenCalled();
      expect(miqObserveRequest).not.toHaveBeenCalled();
    });

    it('calls miqObserveRequest when given observe: true', function() {
      miqSendOneTrans('/foo', { observe: true });
      expect(miqJqueryRequest).not.toHaveBeenCalled();
      expect(miqObserveRequest).toHaveBeenCalled();
    });
  });

  describe('miqProcessObserveQueue', function() {
    it('queues itself when already processing', function() {
      spyOn(window, 'setTimeout');

      ManageIQ.observe.processing = true;
      ManageIQ.observe.queue = [{}];

      miqProcessObserveQueue();

      expect(setTimeout).toHaveBeenCalled();
    });

    context('with nonempty queue', function() {
      var obj = {};

      beforeEach(function() {
        spyOn(window, 'miqJqueryRequest').and.callFake(function() {
          return { then: function(a, b) { /* nope */ } };
        });

        ManageIQ.observe.processing = false;

        ManageIQ.observe.queue = [{
          url: '/foo',
          options: obj,
        }];
      });

      it('sets processing', function() {
        miqProcessObserveQueue();
        expect(ManageIQ.observe.processing).toBe(true);
      });

      it('calls miqJqueryRequest', function() {
        miqProcessObserveQueue();
        expect(miqJqueryRequest).toHaveBeenCalledWith('/foo', obj);
      });
    });

    var deferred = { resolve: function() {} , reject: function() {} };

    context('on success', function() {
      beforeEach(function() {
        ManageIQ.observe.processing = false;
        ManageIQ.observe.queue = [{ deferred: deferred }];

        spyOn(window, 'miqJqueryRequest').and.callFake(function() {
          return { then: function(ok, err) { ok() } };
        });
      });

      it('unsets processing', function() {
        miqProcessObserveQueue();
        expect(ManageIQ.observe.processing).toBe(false);
      });

      it('resolves the promise', function() {
        spyOn(deferred, 'resolve');

        miqProcessObserveQueue();
        expect(deferred.resolve).toHaveBeenCalled();
      });
    });

    context('on failure', function() {
      beforeEach(function() {
        ManageIQ.observe.processing = false;
        ManageIQ.observe.queue = [{ deferred: deferred }];

        spyOn(window, 'miqJqueryRequest').and.callFake(function() {
          return { then: function(ok, err) { err() } };
        });
      });

      it('unsets processing', function() {
        miqProcessObserveQueue();
        expect(ManageIQ.observe.processing).toBe(false);
      });

      it('rejects the promise', function() {
        spyOn(deferred, 'reject');

        miqProcessObserveQueue();
        expect(deferred.reject).toHaveBeenCalled();
      });

      it('displays an alert message', function() {
        spyOn(window, 'add_flash');

        miqProcessObserveQueue();
        expect(add_flash).toHaveBeenCalled();
      });
    });
  });

  describe('miqObserveRequest', function() {
    beforeEach(function() {
      spyOn(window, 'miqProcessObserveQueue');

      ManageIQ.observe.processing = false;
      ManageIQ.observe.queue = [];
    });

    it('sets observe: true on options', function() {
      miqObserveRequest('/foo', {});
      expect(ManageIQ.observe.queue[0].options.observe).toBe(true);
    });

    it('sets observe: true on options even without options', function() {
      miqObserveRequest('/foo');
      expect(ManageIQ.observe.queue[0].options.observe).toBe(true);
    });

    it('adds to queue', function() {
      miqObserveRequest('/foo');
      expect(ManageIQ.observe.queue[0].url).toBe('/foo');
    });

    it('calls miqProcessObserveQueue', function() {
      miqObserveRequest('/foo');
      expect(miqProcessObserveQueue).toHaveBeenCalled();
    });

    it('returns a Promise', function() {
      expect(miqObserveRequest('/foo')).toEqual(jasmine.any(Promise));
    });
  });

  describe('miqAjax', function() {
    context('on failure', function() {
      beforeEach(function () {
        spyOn(window, 'miqJqueryRequest').and.callFake(function () {
          return {
            catch: function (err) {
              err()
            }
          };
        });
      });

      it('displays an alert on error', function () {
        spyOn(window, 'add_flash');
        miqAjax('/foo', false, {});
        expect(add_flash).toHaveBeenCalled();
      });
    });
  });

  describe('miqJqueryRequest', function() {
    beforeEach(function() {
      spyOn($, 'ajax').and.callFake(function() {
        return { then: function(ok, err) { /* nope */ } };
      });
    });

    it('queues itself when processing observe queue', function() {
      ManageIQ.observe.processing = true;
      ManageIQ.observe.queue = [];

      spyOn(window, 'setTimeout');
      miqJqueryRequest('/foo');

      expect(setTimeout).toHaveBeenCalled();
    });

    it('queues itself when observe queue nonempty', function() {
      ManageIQ.observe.processing = false;
      ManageIQ.observe.queue = [{}];

      spyOn(window, 'setTimeout');
      miqJqueryRequest('/foo');

      expect(setTimeout).toHaveBeenCalled();
    });

    it('doesn\'t try to queue when passed options.observe', function() {
      ManageIQ.observe.processing = true;
      ManageIQ.observe.queue = [{}];

      spyOn(window, 'setTimeout');
      miqJqueryRequest('/foo', { observe: true });

      expect(setTimeout).not.toHaveBeenCalled();
    });

    it('returns a Promise', function() {
      expect(miqJqueryRequest('/foo')).toEqual(jasmine.any(Promise));
    });
  });

  describe('miqSelectPickerEvent', function () {
    beforeEach(function () {
      var html = '<input id="miq-select-picker-1" value="bar">';
      setFixtures(html);
    });

    it("doesn't die on null callback", function() {
      spyOn(window, 'miqObserveRequest');
      spyOn(_, 'debounce').and.callFake(function(fn, opts) {
        return fn;
      });

      miqSelectPickerEvent('miq-select-picker-1', '/foo/');

      $('#miq-select-picker-1').val('quux').trigger('change');

      expect(miqObserveRequest).toHaveBeenCalledWith('/foo/?miq-select-picker-1=quux', {
        no_encoding: true
      });
    });

    it("sends beforeSend & complete options to miqObserveRequest", function() {
      spyOn(window, 'miqObserveRequest');
      spyOn(_, 'debounce').and.callFake(function(fn, opts) {
        return fn;
      });

      miqSelectPickerEvent('miq-select-picker-1', '/foo/', {beforeSend: true, complete: true});

      $('#miq-select-picker-1').val('1').trigger('change');

      expect(miqObserveRequest).toHaveBeenCalledWith('/foo/?miq-select-picker-1=1', {
        no_encoding: true,
        beforeSend: true,
        complete: true,
      });
    });

    it("sets beforeSend & complete options using data-miq_sparkle_on & data-miq_sparkle_off", function() {
      var html = [
        '<select class="selectpicker" id="miq-select-picker-1" name="miq-select-picker-1" data-miq_sparkle_on="true" data-miq_sparkle_off="true">',
        '  <option value="one">1</option>',
        '  <option value="two" selected="selected">2</option>',
        '</select>',
      ].join("\n");

      setFixtures(html);
      spyOn(window, 'miqObserveRequest');
      spyOn(_, 'debounce').and.callFake(function(fn, opts) {
        return fn;
      });

      miqSelectPickerEvent('miq-select-picker-1', '/foo/');

      $('#miq-select-picker-1').val('one').trigger('change');

      expect(miqObserveRequest).toHaveBeenCalledWith('/foo/?miq-select-picker-1=one', {
        no_encoding: true,
        beforeSend: true,
        complete: true,
      });
    });
  });

  describe('miqUncompressedId', function () {
    it('returns uncompressed id unchanged', function() {
      expect(miqUncompressedId('123')).toEqual('123');
      expect(miqUncompressedId('12345678901234567890')).toEqual('12345678901234567890');
    });

    it('uncompresses compressed id', function() {
      expect(miqUncompressedId('1r23')).toEqual('1000000000023');
      expect(miqUncompressedId('999r123456789012')).toEqual('999123456789012');
    });
  });

  describe('miqFormatNotification', function () {
    context('single placeholder', function () {
      it('replaces placeholders with bindings', function () {
        expect(miqFormatNotification('¯\_%{dude}_/¯', {dude: { text: '(ツ)' }})).toEqual('¯\_(ツ)_/¯');
      });
    });

    context('multiple placeholders', function () {
      it('replaces placeholders with bindings', function () {
        expect(miqFormatNotification('%{dude}︵ %{table}', {dude: { text: '(╯°□°）╯' }, table: {text: '┻━┻'}})).toEqual('(╯°□°）╯︵ ┻━┻');
      });
    });

    context('same placeholder multiple times', function () {
      it('replaces placeholders with bindings', function () {
        expect(miqFormatNotification('( %{eye}▽%{eye})/', {eye: { text: 'ﾟ' }})).toEqual('( ﾟ▽ﾟ)/');
      });
    });
  });
});

