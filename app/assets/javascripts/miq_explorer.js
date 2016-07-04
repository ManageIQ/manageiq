ManageIQ.explorer = {}

ManageIQ.explorer.updateElement = function(element, options) {
  if ( _.isString(options.legend) ) 
    $('#' + element).html(options.legend);
  else if ( _.isString(options.title) )
    $('#' + element).attr( {'title': options.title});
};

ManageIQ.explorer.buildCalendar = function(options) {
  var skip_days = _.isObject(options.skipDays) ? options.skipDays : undefined;

  ManageIQ.calendar.calDateFrom = options.dateFrom; //# FIXME js_format_date
  ManageIQ.calendar.calDateTo   = options.dateTo;
  ManageIQ.calendar.calSkipDays = skip_days;

  miqBuildCalendar();
}

ManageIQ.explorer.lock_tree = function(tree, lock) {
  $('#' + tree + 'box').dynatree(lock ? 'disable' : 'enable');
  miqDimDiv('#' + tree + '_div', lock);
}

ManageIQ.explorer.process = function(data) {
  /* variables for the expression editor */
  if ( _.isObject(data.expEditor)) {
    if ( _.isObject(data.expEditor.first)) {
      if ( !_.isUndefined(data.expEditor.first.type))
        ManageIQ.expEditor.first.type   = data.expEditor.first.type;
      if ( !_.isUndefined(data.expEditor.first.title))
        ManageIQ.expEditor.first.title  = data.expEditor.first.title;
    }

    if ( _.isObject(data.expEditor.second)) {
      if ( !_.isUndefined(data.expEditor.second.type))
        ManageIQ.expEditor.second.type   = data.expEditor.second.type;
      if ( !_.isUndefined(data.expEditor.second.title))
        ManageIQ.expEditor.second.title  = data.expEditor.second.title;
    }
  }

  miqButtons( data.showMiqButtons ? 'show' : 'hide' );

  if ( _.isString(data.clearTreeCookies) )
    miqDeleteDynatreeCookies(data.clearTreeCookies);

  if ( _.isString(data.accordionSwap) )
    miqAccordionSwap('#accordion .panel-collapse.collapse.in', '#' + data.accordionSwap);

  /* dealing with tree nodes */
  if ( !_.isUndefined(data.addNodes) ) {

    if (data.addNodes.remove)
      miqRemoveNodeChildren(data.addNodes.activeTree, data.addNodes.key);

    miqAddNodeChildren(data.addNodes.activeTree,
                       data.addNodes.key,
                       data.addNodes.osf,
                       data.addNodes.children);
  }


  if ( !_.isUndefined(data.deleteNode) ) {
    var del_node = $('#' + data.deleteNode.activeTree + 'box').
      dynatree('getTree').
      getNodeByKey(data.deleteNode.node);

    del_node.remove();
  }

  if ( !_.isString(data.dashboardUrl) )
    ManageIQ.widget.dashboardUrl = data.dashboardUrl;

  if ( $('#advsearchModal').hasClass('modal fade in') )
    $('#advsearchModal').modal('hide');

  if ( _.isObject(data.updatePartials) )
    _.forEach(data.updatePartials, function (content, element) {
      $('#' + element).html(content);
    });

  if ( _.isObject(data.updateElement) )
    _.forEach(data.updateElement, function (options, element) {
        ManageIQ.explorer.updateElement(element, options);
    });

  if ( _.isObject(data.replacePartials) )
    _.forEach(data.replacePartials, function (content, element) {
      $('#' + element).replaceWith(content);
    });

  if ( _.isObject(data.buildCalendar) )
    ManageIQ.explorer.buildCalendar(data.buildCalendar);

  if ( data.initDashboard ) miqInitDashboardCols();

  if ( data.clearGtlListGrid )
    ManageIQ.grids.gtl_list_grid = undefined;

  if ( _.isObject(data.setVisibility) )
    _.forEach(data.setVisibility, function (visible, element) {
      if ( miqDomElementExists(element) )
        if ( visible )
          $('#' + element).show()
        else
          $('#' + element).hide()
    });

  $('#main_div').scrollTop(0);

  if ( _.isString(data.rightCellText) )
    $('h1#explorer_title > span#explorer_title_text').
      html(data.rightCellText);
  
  if ( _.isObject(data.reloadToolbars) ) {
    _.forEach(data.replacePartials, function (content, element) {
      $('#' + element).html(content);
    });
    miqInitToolbars();
  }

  ManageIQ.record = data.record;

  if ( !_.isUndefined(data.activateNode) ) {
    miqDynatreeActivateNodeSilently(data.activateNode.activeTree, data.activateNode.osf);
  }

  if ( _.isObject(data.lockTrees) ) {
    _.forEach(data.lockTrees, function (lock, tree) {
      ManageIQ.explorer.lock_tree(tree, lock);
    });
  }

  if ( _.isObject(data.chartData) ) {
    ManageIQ.charts.chartData = data.chartData;
    // FIXME:  @out << Charting.js_load_statement(true)
  }

  if ( data.resetChanges ) ManageIQ.changes = null;
  if ( data.resetOneTrans ) ManageIQ.oneTransition.oneTrans = 0;
  if ( data.oneTransIE ) ManageIQ.oneTransition.IEButtonPressed = true;

  if ( _.isString( data.focus ) ) {
    var element = $('#' + data.focus);
    if ( element.length ) element.focus();
  }

  // FIXME: change 'clear_search_show_or_hide' to bool
  if ( _.isString(data.clearSearch) )
    if ( 'show' == data.clearSearch )
      $('#clear_search').show();
    else
      $('#clear_search').hide();

  miqInitMainContent();

  if ( data.hideModal ) $('#quicksearchbox').modal('hide');
  if ( data.initAccords ) miqInitAccordions();

  if ( _.isString(data.ajaxUrl) )
    miqAsyncAjax(data.ajaxUrl);
  else
    miqSparkleOff();

  return null;
};
