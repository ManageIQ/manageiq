//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
//all purpose set of rules, based on http://code.google.com/p/validation-js
dhtmlxValidation=function(){};
dhtmlxValidation.prototype={
	trackInput:function(el,rule,callback_error,callback_correct){
			dhtmlxEvent(el,"keyup",function(e){ 
				if (dhtmlxValidation._timer) {
					window.clearTimeout(dhtmlxValidation._timer);
					dhtmlxValidation._timer = null;
				}
				dhtmlxValidation._timer = window.setTimeout(function(){

					if (!dhtmlxValidation.checkInput(el,rule)){
						if(!callback_error || callback_error(el,el.value,rule))
							el.className+=" dhtmlx_live_validation_error";
					} else {
						el.className=el.className.replace(/[ ]*dhtmlx_live_validation_error/g,"");
						if (callback_correct)
							callback_correct(el,el.value,rule);
					}
				
				},250);
			});
	},
	checkInput:function(input,rule){
		return this.checkValue(input.value,rule);
	},
	checkValue:function(value,rule){
		if (typeof rule=="string")
			rule = rule.split(",");
			
		var final_res=true;
		for (var i=0; i<rule.length; i++){
			if (!this["is"+rule[i]])
				alert("Incorrect validation rule: "+rule[i]);
			else
				final_res=final_res&&this["is"+rule[i]](value);;
		}
		return final_res;
	},
	isEmpty: function(value) {
		return value == '';
	},
	isNotEmpty: function(value) {
		return !value == '';
	},
	isValidBoolean: function(value) {
		return !!value.toString().match(/^(0|1|true|false)$/);
	},
	isValidEmail: function(value) {
		return !!value.toString().match(/(^[a-z0-9]([0-9a-z\-_\.]*)@([0-9a-z_\-\.]*)([.][a-z]{3})$)|(^[a-z]([0-9a-z_\.\-]*)@([0-9a-z_\-\.]*)(\.[a-z]{2,4})$)/i); 
	},
	isValidInteger: function(value) {
		return !!value.toString().match(/(^-?\d+$)/);
	},
	isValidNumeric: function(value) {
		return !!value.toString().match(/(^-?\d\d*[\.|,]\d*$)|(^-?\d\d*$)|(^-?[\.|,]\d\d*$)/);
	},
	isValidAplhaNumeric: function(value) {
		return !!value.toString().match(/^[_\-a-z0-9]+$/gi);
	},
	// 0000-00-00 00:00:00 to 9999:12:31 59:59:59 (no it is not a "valid DATE" function)
	isValidDatetime: function(value) {
		var dt = value.toString().match(/^(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})$/);
		return dt && !!(dt[1]<=9999 && dt[2]<=12 && dt[3]<=31 && dt[4]<=59 && dt[5]<=59 && dt[6]<=59) || false;
	},
	// 0000-00-00 to 9999-12-31
	isValidDate: function(value) {
		var d = value.toString().match(/^(\d{4})-(\d{2})-(\d{2})$/);
		return d && !!(d[1]<=9999 && d[2]<=12 && d[3]<=31) || false;
	},
	// 00:00:00 to 59:59:59
	isValidTime: function(value) {
		var t = value.toString().match(/^(\d{1,2}):(\d{1,2}):(\d{1,2})$/);
		return t && !!(t[1]<=24 && t[2]<=59 && t[3]<=59) || false;
	},
	// 0.0.0.0 to 255.255.255.255
	isValidIPv4: function(value) { 
		var ip = value.toString().match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
		return ip && !!(ip[1]<=255 && ip[2]<=255 && ip[3]<=255 && ip[4]<=255) || false;
	},
	isValidCurrency: function(value) { // Q: Should I consider those signs valid too ? : ¢|€|₤|₦|¥
		return value.toString().match(/^\$?\s?\d+?[\.,\,]?\d+?\s?\$?$/) && true || false;
	},
	// Social Security Number (999-99-9999 or 999999999)
	isValidSSN: function(value) {
		return value.toString().match(/^\d{3}\-?\d{2}\-?\d{4}$/) && true || false;
	},
	// Social Insurance Number (999999999)
	isValidSIN: function(value) {
		return value.toString().match(/^\d{9}$/) && true || false;
	}	
};
dhtmlxValidation=new dhtmlxValidation();
//extension for the grid
dhtmlXGridObject.prototype.enableValidation=function(mode,live){
	mode=convertStringToBoolean(mode);
	if (mode){
		this._validators={ data:[] };
	}else
		this._validators=false;
		
	if (arguments.length>1)
		this._validators._live=live;
	if (!this._validators._event)
		this._validators._event=this.attachEvent("onEditCell",this.validationEvent);
		
	};
dhtmlXGridObject.prototype.setColValidators=function(vals){
	if (!this._validators) this.enableValidation(true);
	if (typeof vals == "string") vals=vals.split(this.delim);
	this._validators.data=vals;
};
dhtmlXGridObject.prototype.validationEvent=function(stage,id,ind,newval,oldval){
	var v=this._validators; 
	if (!v) return true; // validators disabled
	var rule=(v.data[ind]||this.cells(id,ind).getAttribute("validate"))||"";
	
	if (stage==1 && rule){
		var ed = this.editor||(this._fake||{}).editor;
		if (!ed) return true; //event was trigered by checkbox
		ed.cell.className=ed.cell.className.replace(/[ ]*dhtmlx_validation_error/g,"");
		if (v._live){
			var grid=this;
			dhtmlxValidation.trackInput(ed.getInput(),rule,function(element,value,rule){
				return grid.callEvent("onLiveValidationError",[id,ind,value,element,rule]);
			},function(element,value,rule){
				return grid.callEvent("onLiveValidationCorrect",[id,ind,value,element,rule]);
			});
		}
	}

	if (stage==2)
		this.validateCell(id,ind,rule,newval);
	
	return true;
};

dhtmlXGridObject.prototype.validateCell=function(id,ind,rule,value){
	rule=rule||(this._validators.data[ind]||this.cells(id,ind).getAttribute("validate"));
	value=value||this.cells(id,ind).getValue();
	if (!rule) return;
	var cell = this.cells(id,ind).cell;

	var result = true;
	if (typeof rule == "string")
		rule = rule.split(this.delim);
		
	for (var i=0; i < rule.length; i++) {
		if (!dhtmlxValidation.checkValue(value,rule[i])){
			if (this.callEvent("onValidationError",[id,ind,value,rule[i]]))
				cell.className+=" dhtmlx_validation_error";
			result = false;
		}
	}
	if (result){
		this.callEvent("onValidationCorrect",[id,ind,value,rule]);
		cell.className=cell.className.replace(/[ ]*dhtmlx_validation_error/g,"");		
	}
	return result;
};