//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*     @desc: enables or disables options auto positioning
*     @param: flag - (boolean) true/false
*     @type: public
*/
dhtmlXCombo.prototype.enableOptionAutoPositioning = function(fl){
	if(!this.ListAutoPosit) this.ListAutoPosit = 1;
	this.attachEvent("onOpen",function(){this._setOptionAutoPositioning(fl);})
	this.attachEvent("onXLE",function(){this._setOptionAutoPositioning(fl);})
	
}

/**
*     @desc: set options auto positioning mode enables/disables
*     @param: flag - (boolean) true/false
*     @type: private
*/
dhtmlXCombo.prototype._setOptionAutoPositioning = function(fl){

	if((typeof(fl)!="undefined")&&(!convertStringToBoolean(fl))){
		this.ListPosition = "Bottom";
		this.ListAutoPosit = 0;
		return true
	}
	
	var pos = this.getPosition(this.DOMelem);
	var bottom = this._getClientHeight() - pos[1] - this.DOMelem.offsetHeight; 
	var height = (this.autoHeight)?(this.DOMlist.scrollHeight):parseInt(this.DOMlist.offsetHeight);
	
	if((bottom < height)&&(pos[1] > height)){
		this.ListPosition = "Top";
	}
	else this.ListPosition = "Bottom";
	this._positList();
    if(_isIE)
        this._IEFix(true);
}

/**
*     @desc: gets client height
*     @return: client height
*     @type: private
*/
dhtmlXCombo.prototype._getClientHeight = function(){
	return ((document.compatMode=='CSS1Compat') &&(!window.opera))?document.documentElement.clientHeight:document.body.clientHeight;
}

/**
*     @desc: set width of combo list
*     @param: width - (number) width
*     @type: public
*/

dhtmlXCombo.prototype.setOptionWidth = function(width){
	if(arguments.length > 0){
		this.DOMlist.style.width = width+"px";
     	if (this.DOMlistF) this.DOMlistF.style.width = width+"px";
	}
}

/**
*     @desc: set height of combo list
*     @param: height - (number) height
*     @type: public
*/

dhtmlXCombo.prototype.setOptionHeight = function(height){
	
	if(arguments.length>0){
		if(_isIE)
			this.DOMlist.style.height = this.DOMlistF.style.height =  height+"px";
		else
			this.DOMlist.style.height = height+"px";
		if(this.DOMlistF)
		this.DOMlistF.style.height = this.DOMlist.style.height;
		this._positList();
		if(_isIE)
			this._IEFix(true);
	}
	
}

/**
*     @desc: enables or disables options auto width 
*     @param: flag - (boolean) true/false
*     @type: public
*/
dhtmlXCombo.prototype.enableOptionAutoWidth = function(fl){
	if(!this._listWidthConf) this._listWidthConf = this.DOMlist.offsetWidth;
	if(arguments.length == 0){ var fl = 1; }
	if(convertStringToBoolean(fl)) {
		this.autoOptionWidth = 1;
		this.awOnOpen = this.attachEvent("onOpen",function(){this._setOptionAutoWidth()});
		this.awOnXLE = this.attachEvent("onXLE",function(){this._setOptionAutoWidth()});
	}
	else {
		if(typeof(this.awOnOpen)!= "undefined"){
			this.autoOptionWidth = 0;	
			this.detachEvent(this.awOnOpen);
			this.detachEvent(this.awOnXLE);
			this.setOptionWidth(this._listWidthConf);
		}
	}
} 

/**
*     @desc: set options auto width 
*     @param: flag - (boolean) true/false
*     @type: private
*/
dhtmlXCombo.prototype._setOptionAutoWidth = function(){
	var isScroll = !this.ahOnOpen&&this.DOMlist.scrollHeight>this.DOMlist.offsetHeight;
	this.setOptionWidth(1); 
    var x = this.DOMlist.offsetWidth;
	for ( var i=0; i<this.optionsArr.length; i++){
		var optWidth = (_isFF)?(this.DOMlist.childNodes[i].scrollWidth - 2):this.DOMlist.childNodes[i].scrollWidth;
		if (optWidth > x){
       		x = this.DOMlist.childNodes[i].scrollWidth;
		}
	}
	x += isScroll?18:0;
	
	this.setOptionWidth((this.DOMelem.offsetWidth>x)?this.DOMelem.offsetWidth:x+2);
}

/**
*     @desc: enables or disables list auto height 
*     @param: flag - (boolean) true/false
*     @param: maxHeight - (int) height limitation (if a list height is bigger than maxHeight, a vertical scroll appears)
*     @type: public
*/
dhtmlXCombo.prototype.enableOptionAutoHeight = function(fl,maxHeight){
	if(!this._listHeightConf) this._listHeightConf = (this.DOMlist.style.height=="")?100:parseInt(this.DOMlist.style.height);
	if(arguments.length==0) var fl = 1; 
	this.autoHeight = convertStringToBoolean(fl);
    var combo = this;
	if(this.autoHeight){
        var f = function(){
			window.setTimeout(function(){combo._setOptionAutoHeight(fl,maxHeight)},1)
        }
		this.ahOnOpen = this.attachEvent("onOpen",f);
        if(!this.awOnOpen)
		    this.ahOnXLE = this.attachEvent("onXLE",f);
        var t;
        this.ahOnKey = this.attachEvent("onKeyPressed",function(){
            if(!this._filter)
                return;
            if(t)
                window.clearTimeout(t);
            window.setTimeout(function(){
                if(combo.DOMlist.style.display=="block")
                    combo._setOptionAutoHeight(fl,maxHeight);
            },50)
        });
	}
	else {
		if(typeof(this.ahOnOpen)!= "undefined"){
			this.detachEvent(this.ahOnOpen);
            if(this.ahOnXLE)
			    this.detachEvent(this.ahOnXLE);
            if(this.ahOnKey)
                this.detachEvent(this.ahOnKey);
			this.setOptionHeight(this._listHeightConf);
		}
	}
	
}
 
/**
*     @desc: set auto height 
*     @param: flag - (boolean) true/false
*     @param: maxHeight - (int) height limitation (if a list height is bigger than maxHeight, a vertical scroll appears)
*     @type: private
*/
dhtmlXCombo.prototype._setOptionAutoHeight = function(fl,maxHeight){
	if(convertStringToBoolean(fl)){
		
		this.setOptionHeight(1); 
		var height = 0;
		
		if (this.optionsArr.length > 0){
			if(this.DOMlist.scrollHeight > this.DOMlist.offsetHeight){
  				height= this.DOMlist.scrollHeight + 2;
				
			}
			else height= this.DOMlist.offsetHeight;
			if((arguments.length > 1)&&(maxHeight)){
				var maxHeight = parseInt(maxHeight);
				height = (height>maxHeight)?maxHeight:height;
			}
			
			this.setOptionHeight(height)
		}
                else this.DOMlist.style.display="none";
	}
} 
      
