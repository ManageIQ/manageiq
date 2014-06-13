/*SET EVENT HANDLERS*/
//#events_basic:21092006{
   /**
   *     @desc: set function called when row selected  ( event is async )
   *     @param: func - event handling function (or its name)
   *     @param: anyClick - call handler on any click event, react only on changed row by default
   *     @type: deprecated
   *     @topic: 10
   *     @event: onRowSelect
   *     @eventdesc: Event raised immideatly after row was clicked.
   *     @eventparam:  ID of clicked row
   *     @eventparam:  index of clicked cell
   */
   dhtmlXGridObject.prototype.setOnRowSelectHandler = function(func,anyClick){
        this.attachEvent("onRowSelect",func);
      this._chRRS=(!convertStringToBoolean(anyClick));
   }


   /**
   *     @desc: set function called on grid scrolling
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *     @event: onScroll
   *     @eventdesc: Event raised immideatly after scrolling occured
   *     @eventparam:  scroll left
   *     @eventparam:  scroll top
   */
   dhtmlXGridObject.prototype.setOnScrollHandler = function(func){
        this.attachEvent("onScroll",func);
   }

   /**
   *     @desc: set function called when cell editted
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *   @event: onEditCell
   *     @eventdesc: Event raises 1-3 times depending on cell type and settings
   *     @eventparam:  stage of editting (0-before start[can be canceled if returns false],1-editor opened,2-editor closed)
   *     @eventparam:  ID or row
   *     @eventparam:  index of cell
   *     @eventparam:  new value ( only for stage 2 )
   *     @eventparam:  old value ( only for stage 2 )
   *     @returns:   for stage (0) - false - deny editing; for stag (2) - false - revert to old value, (string) - set (string) instead of new value
   */
   dhtmlXGridObject.prototype.setOnEditCellHandler = function(func){
        this.attachEvent("onEditCell",func);
   }
   /**
   *     @desc: set function called when checkbox or radiobutton was clicked
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *     @event: onCheckbox
   *     @eventdesc: Event raises after state was changed.
   *     @eventparam:  ID or row
   *     @eventparam:  index of cell
   *     @eventparam:  state of checkbox/radiobutton
   */
   dhtmlXGridObject.prototype.setOnCheckHandler = function(func){
        this.attachEvent("onCheckbox",func);
   }

   /**
   *     @desc: set function called when user press Enter
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *   @event: onEnter
   *     @eventdesc: Event raised immideatly after Enter pressed.
   *     @eventparam:  ID or row
   *     @eventparam:  index of cell
   */
   dhtmlXGridObject.prototype.setOnEnterPressedHandler = function(func){
        this.attachEvent("onEnter",func);
   }

   /**
   *     @desc: set function called before row removed from grid
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *      @event: onBeforeRowDeleted
   *     @eventdesc: Event raised right before row deleted (if returns false, deletion canceled)
   *     @eventparam:  ID or row
   */
   dhtmlXGridObject.prototype.setOnBeforeRowDeletedHandler = function(func){
        this.attachEvent("onBeforeRowDeleted",func);
   }
   /**
   *     @desc: set function called after row added to grid
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *      @event: onRowAdded
   *     @eventdesc: Event raised right after row was added to grid
   *     @eventparam:  ID or row
   */
   dhtmlXGridObject.prototype.setOnRowAddedHandler = function(func){
        this.attachEvent("onRowAdded",func);
   }

   /**
   *     @desc: set function called when row added/deleted or grid reordered
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *     @event: onGridReconstructed
   *     @eventdesc: Event raised immideatly after row was clicked.
   *     @eventparam:  grid object
   */
   dhtmlXGridObject.prototype.setOnGridReconstructedHandler = function(func){
        this.attachEvent("onGridReconstructed",func);
   }
/**
*     @desc: set function called on each resizing itteration
*     @param: func - event handling function
*     @type: deprecated

*     @topic: 10
*     @event:  onResize
*     @eventdesc: event fired on each resize itteration
*     @eventparam: cell index
*     @eventparam: cell width
*     @eventparam: grid object
*     @eventreturns: if event returns false - the resizig denied
*/
	dhtmlXGridObject.prototype.setOnResize=function(func){
                this.attachEvent("onResize",func);
    };
       
//#}

//#__pro_feature:21092006{
//#events_adv:21092006{
/**
*     @desc: set function called moment before row selected in grid
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onBeforeSelect
*     @eventdesc: event fired moment before row in grid get selection
*     @eventparam: new selected row
*     @eventparam: old selected row
*     @eventreturns: false - block selection
*/
   dhtmlXGridObject.prototype.setOnBeforeSelect=function(func){
                this.attachEvent("onBeforeSelect",func);
    };
/**
*     @desc: set function called after row created
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onRowCreated
*     @eventdesc: event fired after row created in grid, and filled with data
*     @eventparam: row id
*     @eventparam: row object
*     @eventparam: related xml ( if available )
*/
   dhtmlXGridObject.prototype.setOnRowCreated=function(func){
                this.attachEvent("onRowCreated",func);
    };

/**
*     @desc: set function called after xml loading/parsing ended
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onXLE
*     @eventdesc: event fired simultaneously with ending XML parsing, new items already available in tree
*     @eventparam: grid object
*     @eventparam: count of nodes added
*/
   dhtmlXGridObject.prototype.setOnLoadingEnd=function(func){
                this.attachEvent("onXLE",func);
    };

/**
*     @desc: set function called after value of cell changed by user actions
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onCellChanged
*     @eventdesc: event fired after value was changed
*     @eventparam: row ID
*     @eventparam: cell index
*     @eventparam: new value
*/
   dhtmlXGridObject.prototype.setOnCellChanged=function(func){
                this.attachEvent("onCellChanged",func);
		    }; 
/**
*     @desc: set function called before xml loading started
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event: onXLS
*     @eventdesc: event fired before request for new XML sent to server
*     @eventparam: grid object
*/
   dhtmlXGridObject.prototype.setOnLoadingStart=function(func){
                this.attachEvent("onXLS",func);
    };




/**
*     @desc: set function called before sorting of data started, didn't occur while calling grid.sortRows
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onBeforeSorting
*     @eventdesc: event called before sorting of data started
*     @eventparam: index of sorted column
*     @eventparam: grid object
*     @eventparam: direction of sorting asc/desc
*     @eventreturns: if event returns false - the sorting denied
*/
   dhtmlXGridObject.prototype.setOnColumnSort=function(func){
            this.attachEvent("onBeforeSorting",func);
        };

   /**
   *     @desc: set function called when row selection changed
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *      @edition: Professional
   *     @event: onSelectStateChanged
   *     @eventdesc: Event raised immideatly after selection state was changed
   *     @eventparam:  ID or list of IDs of selected row(s)
   */
   dhtmlXGridObject.prototype.setOnSelectStateChanged = function(func){
        this.attachEvent("onSelectStateChanged",func);
   }

   /**
   *     @desc: set function called when row was dbl clicked
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *      @edition: Professional
   *      @event: onRowDblClicked
   *     @eventdesc: Event raised right after row was double clicked, before cell editor opened by dbl click. If retuns false, event canceled;
   *     @eventparam:  ID or row
   *     @eventparam:  index of column
   */
   dhtmlXGridObject.prototype.setOnRowDblClickedHandler = function(func){
        this.attachEvent("onRowDblClicked",func);
   }

   /**
   *     @desc: set function called when header was clicked
   *     @param: func - event handling function (or its name)
   *     @type: deprecated
   *     @topic: 10
   *     @edition: Professional
   *     @event: onHeaderClick
   *     @eventdesc: Event raised right after header was clicked, before sorting or any other actions;
   *     @eventparam:  index of column
   *     @eventparam:  related javascript event object   
   *     @eventreturns: if event returns false - defaul action denied
   */
   dhtmlXGridObject.prototype.setOnHeaderClickHandler = function(func){
        this.attachEvent("onHeaderClick",func);
   }



//#}
//#}


/**
*     @desc: set function called after resizing finished
*     @param: func - event handling function
*     @type: deprecated
*     @topic: 10
*     @event:  onResizeEnd
*     @eventdesc: event fired after resizing of column finished
*     @eventparam: grid object
*/
   dhtmlXGridObject.prototype.setOnResizeEnd=function(func){
                this.attachEvent("onResizeEnd",func);
    };
    
    
/**
*     @desc: set event handler, which will be called immideatly before showing context menu
*     @param: func - user defined function
*     @type: deprecated
*     @event: onBeforeContextMenu
*     @eventdesc: Event raised immideatly before showing context menu
*     @eventparam:  ID of clicked row
*     @eventparam:  index of cell column
*     @eventparam:  grid object
*     @eventreturns: if event returns false, then context menu is not shown
*     @topic: 0,10
*/
   dhtmlXGridObject.prototype.setOnBeforeContextMenu=function(func){
            this.attachEvent("onBeforeContextMenu",func);
    };

/**
*     @desc: set event handler, which will be called immideatly after right mouse button click on grid row
*     @param: func - user defined function
*     @type: deprecated
*     @event: onRightClick
*     @eventdesc: Event raised immideatly after right mouse button clicked on grid row
*     @eventparam:  ID of clicked row
*     @eventparam:  index of cell column
*     @eventparam:  event object
*     @eventreturns: if event returns false, then dhtmlxMenu integration disabled
*     @topic: 0,10
*/
dhtmlXGridObject.prototype.setOnRightClick=function(func){
   this.attachEvent("onRightClick",func);
};


 /**
*     @desc: set function called after key pressed in grid
*     @param: func - event handling function
*     @type: depricated
*     @edition: Professional
*     @topic: 10
*     @event:  onKeyPress
*     @eventdesc: event fired after key pressed but before default key processing started
*     @eventparam: key code
*     @eventparam: control key flag
*     @eventparam: shift key flag
*     @eventreturns: false - block defaul key processing
*/
   dhtmlXGridObject.prototype.setOnKeyPressed=function(func){
                this.attachEvent("onKeyPress",func);
    };
    

/**
*     @desc: set function called when drag-and-drop event occured
*     @param: aFunc - event handling function
*     @type: deprecated
*     @topic: 10
*     @event:    onDrag
*     @eventdesc: Event occured after item was dragged and droped on another item, but before item moving processed.
      Event also raised while programmatic moving nodes.
*     @eventparam:  ID of source item
*     @eventparam:  ID of target item
*     @eventparam:  source grid object
*     @eventparam:  target grid object
*     @eventparam:  index of column from which drag started
*     @eventparam:  index of column in which drop occurs
*     @eventreturn:  true - confirm drag-and-drop; false - deny drag-and-drop;
*/
dhtmlXGridObject.prototype.setDragHandler=function(func){ this.attachEvent("onDrag",func); }    



/**
*     @desc: set function called after drag-and-drap event occured
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onDrop
*     @eventdesc:  Event raised after drag-and-drop processed.
*     @eventparam:  ID of source item
*     @eventparam:  ID of target item
*     @eventparam:  ID of droped item (has sense for mercy drag-n-drop)
*     @eventparam:  source grid object
*     @eventparam:  target grid object
*     @eventparam:  index of column from which drag started
*     @eventparam:  index of column in which drop occurs
*/
dhtmlXGridObject.prototype.setDropHandler=function(func){  this.attachEvent("onDrop",func); }


/**
*     @desc: set function called when drag moved over potencial landing
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onDragIn
*     @eventdesc:  Event raised if drag moved over potencial landing
*     @eventparam:  ID of source item
*     @eventparam:  ID of target item
*     @eventparam:  source grid object
*     @eventparam:  target grid object
*     @eventreturn:  true - allow landing; false - deny landing;
*/
dhtmlXGridObject.prototype.setDragInHandler=function(func){  this.attachEvent("onDragIn",func); };



/**
*     @desc: set function called on start of column moving operation
*     @param: func - event handling function
*     @type: deprecated 
*     @edition: Professional
*     @topic: 10
*     @event:  onBeforeCMove
*     @eventdesc: event called on start of column moving operation
*     @eventparam: index of moved column
*     @eventparam: index of new position
*     @eventreturns: if event returns false - the moving denied
*/
   dhtmlXGridObject.prototype.setOnBeforeColumnMove=function(func){
            this.attachEvent("onBeforeCMove",func);
        };

/**
*     @desc: set function called after column moved
*     @param: func - event handling function
*     @type: deprecated
*     @edition: Professional
*     @topic: 10
*     @event:  onAfterCMove
*     @eventdesc: event called after  column moved
*     @eventparam: index of moved column
*     @eventparam: index of new position
*/
   dhtmlXGridObject.prototype.setOnAfterColumnMove=function(func){
            this.attachEvent("onAfterCMove",func);
        };
