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

});
