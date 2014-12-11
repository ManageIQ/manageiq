// Functions used by MIQ for the dhtmlxcombo control

// Handle combo changed
function miqComboChanged(key) {
  miqJqueryRequest(combo_url + '?' + this.name + '=' + this._selOption.value, {beforeSend: true, complete: true});
	return true;
}

// Ignore the selection for checkbox combo boxes, override the text
function miqSelectionIgnore() {
	this.setComboText("Check Options");
}

// Handle checkboxes
function miqComboOnCheck(value, state) {
  miqJqueryRequest(combo_url + '?' + this.name + '=' + value + '_' + state);
	return true;
}
