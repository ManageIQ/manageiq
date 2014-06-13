//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/*
	extra hotkeys
*/
dhtmlXGridObject.prototype._key_events={
			k45_0_0:function(){// INSERT - add new line at current position
				if (!this.editor) this.addRow((new Date()).valueOf(),[],this.row.rowIndex)
            },
			k46_0_0:function(){	//DEL - delete value of current cell on 
				if (!this.editor) this.cells4(this.cell).setValue("");
            }
		};