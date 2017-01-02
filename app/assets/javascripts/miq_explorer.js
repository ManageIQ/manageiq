ManageIQ.explorer = {};

ManageIQ.explorer.updateElement = function(element, options) {
  if (_.isString(options.legend)) {
    $('#' + element).html(options.legend);
  } else if (_.isString(options.title)) {
    $('#' + element).attr( {'title': options.title});
  } else if (_.isString(options.class)) {
    if (options.add) {
      $('#' + element).addClass(options.class);
    } else {
      $('#' + element).removeClass(options.class);
    }
  }
};

ManageIQ.explorer.buildCalendar = function(options) {
  ManageIQ.calendar.calDateFrom = _.isString(options.dateFrom) ? new Date(options.dateFrom) : undefined;
  ManageIQ.calendar.calDateTo = _.isString(options.dateTo) ? new Date(options.dateTo) : undefined;
  ManageIQ.calendar.calSkipDays = _.isObject(options.skipDays) ? options.skipDays : undefined;

  miqBuildCalendar();
};

ManageIQ.explorer.lock_tree = function(tree_name, lock) {
  var tree = miqTreeObject(tree_name);
  if (!tree || "length" in tree) {
    // "length" in tree - because miqTreeObject returns a jquery array when the element doesn't exist
    // https://github.com/patternfly/patternfly-bootstrap-treeview/issues/16
    console.warn("Attempting to lock_tree a tree which doesn't exist", tree_name, lock);
    return;
  }

  lock ? tree.disableAll({silent: true, keepState: true}) : tree.enableAll();
  miqDimDiv('#' + tree_name + '_div', lock);
};

ManageIQ.explorer.clearSearchToggle = function(show) {
  if (show) {
    $('#clear_search').show();
  } else {
    $('#clear_search').hide();
  }
};

ManageIQ.explorer.process = function(data) {
  switch (data.explorer) {
    case 'flash':
      ManageIQ.explorer.processFlash(data);
      break;
    case 'replace_right_cell':
      ManageIQ.explorer.processReplaceRightCell(data);
      break;
    case 'replace_main_div':
      ManageIQ.explorer.processReplaceMainDiv(data);
      break;
    case 'buttons':
      ManageIQ.explorer.processButtons(data);
      break;
    case 'window':
      ManageIQ.explorer.processWindow(data);
      break;
  }
};

ManageIQ.explorer.processWindow = function(data) {
  if (_.isString(data.openUrl)) {
    window.open(data.openUrl);
  }
  ManageIQ.explorer.spinnerOff(data);
};

ManageIQ.explorer.processButtons = function(data) {
  ManageIQ.explorer.miqButtons(data);
};

ManageIQ.explorer.processReplaceMainDiv = function(data) {
  ManageIQ.explorer.updatePartials(data);
};

ManageIQ.explorer.processFlash = function(data) {
  ManageIQ.explorer.replacePartials(data);
  ManageIQ.explorer.spinnerOff(data);
  ManageIQ.explorer.scrollTop(data);
  ManageIQ.explorer.focus(data);
};

ManageIQ.explorer.replacePartials = function(data) {
  if (_.isObject(data.replacePartials)) {
    _.forEach(data.replacePartials, function (content, element) {
      $('#' + element).replaceWith(content);
    });
  }
};

ManageIQ.explorer.updatePartials = function(data) {
  if (_.isObject(data.updatePartials)) {
    _.forEach(data.updatePartials, function (content, element) {
      $('#' + element).html(content);
    });
  }
};

ManageIQ.explorer.spinnerOff = function(data) {
  if (data.spinnerOff) {
    miqSparkle(false);
  }
};


ManageIQ.explorer.scrollTop = function(data) {
  if (data.scrollTop) {
    $('#main_div').scrollTop(0);
  }
};

ManageIQ.explorer.miqButtons = function(data) {
  miqButtons(data.showMiqButtons ? 'show' : 'hide');
};

ManageIQ.explorer.focus = function(data) {
  if (_.isString(data.focus)) {
    var element = $('#' + data.focus);
    if ( element.length ) element.focus();
  }
}

ManageIQ.explorer.processReplaceRightCell = function(data) {
  /* variables for the expression editor */
  if (_.isObject(data.expEditor)) {
    if (_.isObject(data.expEditor.first)) {
      if (!_.isUndefined(data.expEditor.first.type)) {
        ManageIQ.expEditor.first.type   = data.expEditor.first.type;
      }
      if (!_.isUndefined(data.expEditor.first.title)) {
        ManageIQ.expEditor.first.title  = data.expEditor.first.title;
      }
    }

    if (_.isObject(data.expEditor.second)) {
      if (!_.isUndefined(data.expEditor.second.type)) {
        ManageIQ.expEditor.second.type   = data.expEditor.second.type;
      }
      if (!_.isUndefined(data.expEditor.second.title)) {
        ManageIQ.expEditor.second.title  = data.expEditor.second.title;
      }
    }
  }

  ManageIQ.explorer.miqButtons(data);

  if (_.isString(data.clearTreeCookies)) { miqDeleteTreeCookies(data.clearTreeCookies); }

  if (_.isString(data.accordionSwap)) {
    miqAccordionSwap('#accordion .panel-collapse.collapse.in', '#' + data.accordionSwap + '_accord');
  }

  /* dealing with tree nodes */
  if (!_.isUndefined(data.addNodes)) {

    if (data.addNodes.remove) {
      miqRemoveNodeChildren(data.addNodes.activeTree, data.addNodes.key);
    }

    miqAddNodeChildren(data.addNodes.activeTree,
                       data.addNodes.key,
                       data.addNodes.osf,
                       data.addNodes.nodes);
  }


  if (!_.isUndefined(data.deleteNode)) {
    var del_node = miqTreeFindNodeByKey(data.deleteNode.activeTree, data.deleteNode.node)
    miqTreeObject(data.deleteNode.activeTree).deleteNode(del_node);
  }

  if (_.isString(data.dashboardUrl)) {
    ManageIQ.widget.dashboardUrl = data.dashboardUrl;
  }

  if ($('#advsearchModal').hasClass('modal fade in')) {
    $('#advsearchModal').modal('hide');
  }

  ManageIQ.explorer.updatePartials(data);

  if (_.isObject(data.updateElements)) {
    _.forEach(data.updateElements, function (options, element) {
        ManageIQ.explorer.updateElement(element, options);
    });
  }

  ManageIQ.explorer.replacePartials(data);

  if (_.isObject(data.buildCalendar)) { ManageIQ.explorer.buildCalendar(data.buildCalendar); }

  if (data.initDashboard) { miqInitDashboardCols(); }

  if (data.clearGtlListGrid) { ManageIQ.grids.gtl_list_grid = undefined; }

  if (_.isObject(data.setVisibility))
    _.forEach(data.setVisibility, function (visible, element) {
      if ( miqDomElementExists(element) ) {
        if ( visible ) {
          $('#' + element).show()
        } else {
          $('#' + element).hide()
        }
      }
    });

  ManageIQ.explorer.scrollTop(data);

  if (_.isString(data.rightCellText)) {
    $('h1#explorer_title > span#explorer_title_text')
      .html(data.rightCellText);
  }

  if (_.isArray(data.reloadToolbars) && data.reloadToolbars.length) {
    ManageIQ.angular.rxSubject.onNext({
      redrawToolbar: data.reloadToolbars
    });
  } else if (_.isObject(data.reloadToolbars) && !_.isArray(data.reloadToolbars)) {
    // FIXME remove this branch completely once sure
    console.error('Found a toolbar using the obsolete path! Please report or fix');

    _.forEach(data.reloadToolbars, function (content, element) {
      $('#' + element).html(content);
    });
    miqInitToolbars();
  }

  ManageIQ.record = data.record;

  if (!_.isUndefined(data.activateNode)) {
    miqExpandParentNodes(data.activateNode.activeTree, data.activateNode.osf);
    miqTreeActivateNodeSilently(data.activateNode.activeTree, data.activateNode.osf);
  }

  if (_.isObject(data.lockTrees)) {
    _.forEach(data.lockTrees, function (lock, tree) {
      ManageIQ.explorer.lock_tree(tree, lock);
    });
  }

  if (_.isObject(data.chartData)) {
    ManageIQ.charts.chartData = data.chartData;
    load_c3_charts();
  }

  if (data.resetChanges) { ManageIQ.changes = null; }
  if (data.resetOneTrans) { ManageIQ.oneTransition.oneTrans = 0; }
  if (data.oneTransIE) { ManageIQ.oneTransition.IEButtonPressed = true; }

  ManageIQ.explorer.focus(data);

  if (!_.isUndefined(data.clearSearch)) {
    ManageIQ.explorer.clearSearchToggle(data.clearSearch);
  }

  miqInitMainContent();
  miqInitAccordions();

  if (data.hideModal) { $('#quicksearchbox').modal('hide'); }
  if (data.initAccords) { miqInitAccordions(); }

  if (_.isString(data.ajaxUrl)) {
    miqAsyncAjax(data.ajaxUrl);
  } else {
    miqSparkleOff();
  }

  return null;
};
