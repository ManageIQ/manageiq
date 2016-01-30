describe('dialog_import_export.js', function() {
  describe('#getAndRenderServiceDialogJson', function() {
    var data;

    beforeEach(function() {
      data = 'the data';

      spyOn($, 'getJSON').and.callFake(function() {
        var d = $.Deferred();
        d.resolve(data);
        return d.promise();
      });

      spyOn(window, 'renderServiceDialogJson');
      spyOn(window, 'showSuccessMessage');
    });

    it('renders the service dialogs via the json', function() {
      getAndRenderServiceDialogJson(123, '{"message": "the message"}');
      expect(window.renderServiceDialogJson).toHaveBeenCalledWith(data, 123);
    });

    it('shows the success messages', function() {
      getAndRenderServiceDialogJson(123, '{"message": "the message"}');
      expect(window.showSuccessMessage).toHaveBeenCalledWith('the message');
    });
  });

  describe('#renderServiceDialogJson', function() {
    var checkboxSelector, grid, data, dataView, importFileUploadId;

    beforeEach(function() {
      var html = '';
      html += '<div id="import-grid">';
      html += '</div>';
      setFixtures(html);

      importFileUploadId = 123;
      data = {
        'responseJSON': [{
          id: 321,
          status_icon: 'equal-green'
        }, {
          id: 322,
          status_icon: 'not-equal-green'
        }],
        'status': 200
      };

      var gridConstructor = Slick.Grid;
      var dataViewConstructor = Slick.Data.DataView;
      var checkboxSelectColumnConstructor = Slick.CheckboxSelectColumn;

      spyOn(window.Slick, 'Grid').and.callFake(function() {
        var fakeDataView = new dataViewConstructor();
        grid = new gridConstructor('#import-grid', fakeDataView, []);
        spyOn(grid, 'setSelectionModel');
        spyOn(grid, 'registerPlugin');
        spyOn(grid.getData(), 'getItems').and.callFake(function() {
          return [{id: 321, status_icon: '/equal-green'}, {id: 322, status_icon: '/not-equal-green'}];
        });
        spyOn(grid, 'setSelectedRows');
        spyOn(grid, 'invalidate');
        spyOn(grid, 'render');
        return grid;
      });

      spyOn(window.Slick, 'CheckboxSelectColumn').and.callFake(function() {
        checkboxSelector = new checkboxSelectColumnConstructor();
        spyOn(checkboxSelector, 'getColumnDefinition');
        return checkboxSelector;
      });

      spyOn(window.Slick.Data, 'DataView').and.callFake(function() {
        dataView = new dataViewConstructor();
        spyOn(dataView, 'beginUpdate');
        spyOn(dataView, 'setItems');
        spyOn(dataView, 'endUpdate');
        return dataView;
      });
    });

    it('sets up the slick data view', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(window.Slick.Data.DataView).toHaveBeenCalledWith({inlineFilters: true});
    });

    it('sets up the slick checkbox select column', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(window.Slick.CheckboxSelectColumn).toHaveBeenCalledWith({cssClass: "import-checkbox"});
    });

    it('updates the data view', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(dataView.beginUpdate).toHaveBeenCalled();
    });

    it('sets the items in the data view', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(dataView.setItems).toHaveBeenCalledWith(data);
    });

    it('ends the update of the data view', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(dataView.endUpdate).toHaveBeenCalled();
    });

    it('sets up the slick grid with the selected rows', function() {
      renderServiceDialogJson(data, importFileUploadId);
      expect(grid.setSelectedRows).toHaveBeenCalledWith([321]);
    });
  });
});
