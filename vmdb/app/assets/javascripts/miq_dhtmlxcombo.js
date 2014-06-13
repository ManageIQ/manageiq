// Functions used by MIQ for the dhtmlxcombo control

// Handle combo changed
function miqComboChanged(key) {
	new Ajax.Request(encodeURI(combo_url + "?" + this.name + "=" + this._selOption.value),
                  {
                   asynchronous:true, evalScripts:true,
                   onComplete:function(request){miqSparkle(false);},
                   onLoading:function(request){miqSparkle(true);}
                  }
			);
	return true;
}

// Ignore the selection for checkbox combo boxes, override the text
function miqSelectionIgnore() {
	this.setComboText("Check Options");
}

// Handle checkboxes
function miqComboOnCheck(value, state) {
//	alert("Name: " + this.name + "Value: " + value + " State: " + state);
	new Ajax.Request(encodeURI(combo_url + "?" + this.name + "=" + value + "_" + state),
			{asynchronous:true, evalScripts:true}
			);
	return true;
}
