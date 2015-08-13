//= require_directory ../SlickGrid-2.1/

$.getJSON("get_json?import_file_upload_id=" + import_file_upload_id, function (rows_json) {
  ManageIQ.slick.slickRows = rows_json;

  function myFilter(item) {
    if (item.parent != null) {
      var parent = ManageIQ.slick.slickRows[item.parent];

      while (parent) {
        if (parent._collapsed) {
          return false;
        }
        parent = ManageIQ.slick.slickRows[parent.parent];
      }
    }

    return true;
  };

  var PolicyNameFormatter = function (row, cell, value, columnDef, dataContext) {
    var spacer = "<span style='display:inline-block;height:1px;width:" + (15 * dataContext.indent) + "px'></span>";
    var status_img = "<img src=" + dataContext.status_icon + ">";

    var idx = dataview.getIdxById(dataContext.id);
    if (ManageIQ.slick.slickRows[idx + 1] && ManageIQ.slick.slickRows[idx + 1].indent > ManageIQ.slick.slickRows[idx].indent) {
      if (dataContext._collapsed) {
        return spacer + " <span class='toggle expand'></span>&nbsp;" + status_img + value;
      } else {
        return spacer + " <span class='toggle collapse'></span>&nbsp;" + status_img + value;
      }
    } else {
      return spacer + " <span class='toggle'></span>&nbsp;" + status_img + value;
    }
  };

  var grid;
  var dataview = new Slick.Data.DataView();

  var columns = [
    {id: "title", name: "Details", field: "title", width: 300, formatter: PolicyNameFormatter},
    {id: "msg", name: "Message", field: "msg", width: 300}
  ];

  var options = {
    enableColumnReorder: false,
    asyncEditorLoading: false,
    forceFitColumns: true
  };

  dataview.beginUpdate();
  dataview.setItems(ManageIQ.slick.slickRows);
  dataview.setFilter(myFilter);
  dataview.endUpdate();

  grid = new Slick.Grid("#import_grid", dataview, columns, options);

  grid.onClick.subscribe(function (e, args) {
    if ($(e.target).hasClass("toggle")) {
      var item = dataview.getItem(args.row);
      if (item) {
        if (!item._collapsed) {
          item._collapsed = true;
        } else {
          item._collapsed = false;
        }

        dataview.updateItem(item.id, item);
      }
      e.stopImmediatePropagation();
    }
  });

  // Wire up model events to drive the grid
  dataview.onRowCountChanged.subscribe(function (e, args) {
    grid.updateRowCount();
    grid.render();
  });

  dataview.onRowsChanged.subscribe(function (e, args) {
    grid.invalidateRows(args.rows);
    grid.render();
  });
});
