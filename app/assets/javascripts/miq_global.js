// global variables
if (typeof(ManageIQ) === 'undefined') var ManageIQ = {
  actionUrl: null, // action URL used in JS function miqGridSort
  angularApplication: null, // angular application
  browser: null, // browser name
  controller: null, // stored controller, used to build URL
  changes: null, // indicate if there are unsaved changes
  dynatreeReplacement: null, //
  editor: null, // instance of CodeMirror editor
  sizeTimer: null, // timer for routines to get size of the window
  timelineFilter: null, //
  toolbars: null, // toolbars TODO: about to be removed
  oneTransition: {
    IEButtonPressed: null, // pressed save/reset button identificator
    oneTrans: null, // used to generate Ajax request only once for a drawn screen
  },
  expEditor: {
    prefillCount: 0, //
    first: {
      title: null, //
      type: null, //
    },
    second: {
      title: null, //
      type: null, //
    },
  },
  calendar: { // TODO about to be removed
    calDateFrom: null, // to limit calendar starting
    calDateTo: null, // to limit calendar ending
  },
  charts: {
    chartData: null, // data for charts
    charts: {}, // object with registered charts used in jqplot_register_chart
  },
  grids: {
    grids: null, // stored grids on the screen
    gridColumnWidths: null, // store grid column widths
    xml: null,
  },
  mouse: {
    x: null, // mouse X coordinate for popup menu
    y: null, // mouse Y coordinate for popup menu
  },
  record: {
    parentClass: null, // parent record ID for JS function miqGridSort to build URL
    parentId: null, // parent record ID for JS function miqGridSort to build URL
    recordId: null, // record being displayed or edited
  },
  reportEditor: {
    valueStyles: null,
    prefillCount: 0,
  },
  slick: {
    slickColumns: null,
    slickGrid: null,
    slickRows: null,
    slickDataView: null,
  },
  spinner: {
    spinner: null, // spinner instance
    searchSpinner: null, // search spinner instance
  },
  widget: {
    dashboardUrl: null, // set dashboard widget drag drop url
    menuXml: null,
  },
};
