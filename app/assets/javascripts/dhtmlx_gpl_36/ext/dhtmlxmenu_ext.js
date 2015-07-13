//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/****************************************************************************************************************************************************/
/*								 	EXTENDED MODULE INFO							    */
dhtmlXMenuObject.prototype.extendedModule = "DHXMENUEXT";
/****************************************************************************************************************************************************/
/*								 	ENABLING/DISBLING							    */
/**
*   @desc: enables an item
*   @param: id - item's id to enable
*   @param: state - true|false
*   @type: public
*/
dhtmlXMenuObject.prototype.setItemEnabled = function(id) {
	// modified in 0.4
	this._changeItemState(id, "enabled", this._getItemLevelType(id));
}
/**
*   @desc: disables an item
*   @param: id - item's id to disablei
*   @type: public
*/
dhtmlXMenuObject.prototype.setItemDisabled = function(id) {
	this._changeItemState(id, "disabled", this._getItemLevelType(id));
}
/**
*   @desc: returns true if the item is enabled
*   @param: id - the item to check
*   @type: public
*/
dhtmlXMenuObject.prototype.isItemEnabled = function(id) {
	return (this.itemPull[this.idPrefix+id]!=null?(this.itemPull[this.idPrefix+id]["state"]=="enabled"):false);
}
/* enable/disable sublevel item */
dhtmlXMenuObject.prototype._changeItemState = function(id, newState, levelType) {
	var t = false;
	var j = this.idPrefix + id;
	if ((this.itemPull[j] != null) && (this.idPull[j] != null)) {
		if (this.itemPull[j]["state"] != newState) {
			this.itemPull[j]["state"] = newState;
			if (this.itemPull[j]["parent"] == this.idPrefix+this.topId && !this.context) {
				this.idPull[j].className = "dhtmlxMenu_"+this.skin+"_TopLevel_Item_"+(this.itemPull[j]["state"]=="enabled"?"Normal":"Disabled");
			} else {
				this.idPull[j].className = "sub_item"+(this.itemPull[j]["state"]=="enabled"?"":"_dis");
			}
			
			this._updateItemComplexState(this.idPrefix+id, this.itemPull[this.idPrefix+id]["complex"], false);
			this._updateItemImage(id, levelType);
			// if changeItemState attached to onClick event and changing applies to selected item all selection should be reparsed
			if ((this.idPrefix + this.menuLastClicked == j) && (levelType != "TopLevel")) {
				this._redistribSubLevelSelection(j, this.itemPull[j]["parent"]);
			}
			if (levelType == "TopLevel" && !this.context) { // rebuild style.left and show nested polygons
				// this._redistribTopLevelSelection(id, "parent");
			}
		}
	}
	return t;
}
/****************************************************************************************************************************************************/
/*								 	SET/GET TEXT								    */
/**
*   @desc: returns item's text
*   @param: id - the item
*   @type: public
*/
dhtmlXMenuObject.prototype.getItemText = function(id) {
	return (this.itemPull[this.idPrefix+id]!=null?this.itemPull[this.idPrefix+id]["title"]:"");
}

/**
*   @desc: sets text for the item
*   @param: id - the item
*   @param: text - a new text
*   @type: public
*/
dhtmlXMenuObject.prototype.setItemText = function(id, text) {
	id = this.idPrefix + id;
	if ((this.itemPull[id] != null) && (this.idPull[id] != null)) {
		this._clearAndHide();
		this.itemPull[id]["title"] = text;
		if (this.itemPull[id]["parent"] == this.idPrefix+this.topId && !this.context) {
			// top level
			var tObj = null;
			for (var q=0; q<this.idPull[id].childNodes.length; q++) {
				try { if (this.idPull[id].childNodes[q].className == "top_level_text") tObj = this.idPull[id].childNodes[q]; } catch(e) {}
			}
			if (String(this.itemPull[id]["title"]).length == "" || this.itemPull[id]["title"] == null) {
				if (tObj != null) tObj.parentNode.removeChild(tObj);
			} else {
				if (!tObj) {
					tObj = document.createElement("DIV");
					tObj.className = "top_level_text";
					if (this._rtl && this.idPull[id].childNodes.length > 0) this.idPull[id].insertBefore(tObj,this.idPull[id].childNodes[0]); else this.idPull[id].appendChild(tObj);
				}
				tObj.innerHTML = this.itemPull[id]["title"];
			}
		} else {
			// sub level
			var tObj = null;
			for (var q=0; q<this.idPull[id].childNodes[1].childNodes.length; q++) {
				if (String(this.idPull[id].childNodes[1].childNodes[q].className||"") == "sub_item_text") tObj = this.idPull[id].childNodes[1].childNodes[q];
			}
			if (String(this.itemPull[id]["title"]).length == "" || this.itemPull[id]["title"] == null) {
				if (tObj) {
					tObj.parentNode.removeChild(tObj);
					tObj = null;
					this.idPull[id].childNodes[1].innerHTML = "&nbsp;";
				}
			} else {
				if (!tObj) {
					tObj = document.createElement("DIV");
					tObj.className = "sub_item_text";
					this.idPull[id].childNodes[1].innerHTML = "";
					this.idPull[id].childNodes[1].appendChild(tObj);
				}
				tObj.innerHTML = this.itemPull[id]["title"];
			}
		}
	}
}
/****************************************************************************************************************************************************/
/**
*   @desc: loads menu data from an html and calls onLoadFunction when loading is done
*   @param: object - html data container
*   @param: clearAfterAdd - true|false, removes the container object after the data is loaded
*   @param: onLoadFunction - is called after the data is loaded (but before clearing html content if clear is set to true)
*   @type: public
*/
dhtmlXMenuObject.prototype.loadFromHTML = function(objId, clearAfterAdd, onLoadFunction) {
	//alert(4)
	// this.idPrefix = this._genStr(12);
	this.itemTagName = "DIV";
	if (typeof(objId) == "string") { objId = document.getElementById(objId); }
	this._buildMenu(objId, null);
	this.init();
	if (clearAfterAdd) { objId.parentNode.removeChild(objId); }
	if (onLoadFunction != null) { onLoadFunction(); }
}
/****************************************************************************************************************************************************/
/*								 	SHOW/HIDE								    */
/**
*   @desc: hides an item
*   @param: id - the item to hide
*   @type: public
*/
dhtmlXMenuObject.prototype.hideItem = function(id) {
	this._changeItemVisible(id, false);
}
/**
*   @desc: shows an item
*   @param: id - the item to show
*   @type: public
*/
dhtmlXMenuObject.prototype.showItem = function(id) {
	this._changeItemVisible(id, true);
}
/**
*   @desc: returns true if the item is hidden
*   @param: id - the item to check
*   @type: public
*/
dhtmlXMenuObject.prototype.isItemHidden = function(id) {
	var isHidden = null;
	if (this.idPull[this.idPrefix+id] != null) { isHidden = (this.idPull[this.idPrefix+id].style.display == "none"); }
	return isHidden;
}
/* show/hide item in menu, optimized for version 0.3 */
dhtmlXMenuObject.prototype._changeItemVisible = function(id, visible) {
	var itemId = this.idPrefix+id;
	if (this.itemPull[itemId] == null) return;
	if (this.itemPull[itemId]["type"] == "separator") { itemId = "separator_"+itemId; }
	if (this.idPull[itemId] == null) return;
	this.idPull[itemId].style.display = (visible?"":"none");
	this._redefineComplexState(this.itemPull[this.idPrefix+id]["parent"]);
}
/****************************************************************************************************************************************************/
/*								 	USERDATA								    */
//#menu_userdata:06062008{
/**
*   @desc: sets userdata for an item
*   @param: id - the item
*   @param: name - the name of userdata (string)
*   @param: value - the value of userdata (usually string)
*   @type: public
*/
dhtmlXMenuObject.prototype.setUserData = function(id, name, value) {
	this.userData[this.idPrefix+id+"_"+name] = value;
}

/**
*   @desc: returns item's userdata
*   @param: id - the item
*   @param: name - the name of userdata (string)
*   @type: public
*/
dhtmlXMenuObject.prototype.getUserData = function(id, name) {
	return (this.userData[this.idPrefix+id+"_"+name]!=null?this.userData[this.idPrefix+id+"_"+name]:null);
}
//#}
/****************************************************************************************************************************************************/
/*								 	OPENMODE/TIMEOUT							    */
/**
*   @desc: sets open mode for the menu
*   @param: mode - win|web, the default mode is web, in the win mode a user should click anywhere to hide the menu, in the web mode - just put the mouse pointer out of the menu area
*   @type: public
*/
dhtmlXMenuObject.prototype.setOpenMode = function(mode) {
	if (mode == "win" || mode == "web") this.menuMode = mode; else this.menuMode == "web"; 
}
/**
*   @desc: sets hide menu timeout (web mode only)
*   @param: tm - timeout, ms, 400 default
*   @type: public
*/
dhtmlXMenuObject.prototype.setWebModeTimeout = function(tm) {
	this.menuTimeoutMsec = (!isNaN(tm)?tm:400);
}
/****************************************************************************************************************************************************/
/*								 	DYNAMICAL LOADING							    */
/**
*   @desc: enables dynamic loading of sublevels
*   @param: url - server-side script, transmitted params are action=loadMenu and parentId 
*   @param: icon - true|false, replaces elemet's arrow with loading image while loading
*   @type: public
*/
dhtmlXMenuObject.prototype.enableDynamicLoading = function(url, icon) {
	this.dLoad = true;
	this.dLoadUrl = url;
	this.dLoadSign = (String(this.dLoadUrl).search(/\?/)==-1?"?":"&");
	this.loaderIcon = icon;
	this.init();
}
/* internal, show/hide loader icon */
dhtmlXMenuObject.prototype._updateLoaderIcon = function(id, state) {
	
	if (this.idPull[id] == null) return;
	if (String(this.idPull[id].className).search("TopLevel_Item") >= 0) return;
	// get arrow
	var ind = (this._rtl?0:2);
	if (!this.idPull[id].childNodes[ind]) return;
	if (!this.idPull[id].childNodes[ind].childNodes[0]) return;
	var aNode = this.idPull[id].childNodes[ind].childNodes[0];
	if (String(aNode.className).search("complex_arrow") === 0) aNode.className = "complex_arrow"+(state?"_loading":"");

}
/****************************************************************************************************************************************************/
/*								 	IMAGES									    */
/**
*   @desc: returns item's image - array(img, imgDis)
*   @param: id - the item
*   @type: public
*/
dhtmlXMenuObject.prototype.getItemImage = function(id) {
	var imgs = new Array(null, null);
	id = this.idPrefix+id;
	if (this.itemPull[id]["type"] == "item") {
		imgs[0] = this.itemPull[id]["imgen"];
		imgs[1] = this.itemPull[id]["imgdis"];
	}
	return imgs;
}
/**
*   @desc: sets an image for the item
*   @param: id - the item
*   @param: img - the image for the enabled item (empty string for none)
*   @param: imgDis - the image for the disabled item (empty string for none)
*   @type: public
*/
dhtmlXMenuObject.prototype.setItemImage = function(id, img, imgDis) {
	if (this.itemPull[this.idPrefix+id]["type"] != "item") return;
	this.itemPull[this.idPrefix+id]["imgen"] = img;
	this.itemPull[this.idPrefix+id]["imgdis"] = imgDis;
	this._updateItemImage(id, this._getItemLevelType(id));
}
/**
*   @desc: removes both enabled and disabled item images
*   @param: id - the item
*   @type: public
*/
dhtmlXMenuObject.prototype.clearItemImage = function(id) {
	this.setItemImage(id, "", "");
}
/****************************************************************************************************************************************************/
/*								 	CONTEXT STUFF								    */
/* public: context menu auto open/close enable/disable */
/**
*   @desc: sets to false to prevent showing a contextual menu by a click
*   @param: mode - true/false
*   @type: public
*/
dhtmlXMenuObject.prototype.setAutoShowMode = function(mode) {
	this.contextAutoShow = (mode==true?true:false);
}
/**
*   @desc: sets to false to prevent hiding a contextual menu by a click
*   @param: mode - true/false
*   @type: public
*/
dhtmlXMenuObject.prototype.setAutoHideMode = function(mode) {
	this.contextAutoHide = (mode==true?true:false);
}

/**
*   @desc: sets to true will hide all opened contextual menu polygons on mouseout
*   @param: mode - true/false
*   @type: public
*/
dhtmlXMenuObject.prototype.setContextMenuHideAllMode = function(mode) {
	this.contextHideAllMode = (mode==true?true:false);
}
/**
*   @desc: retutn hide all contextual menu mode
*   @type: public
*/
dhtmlXMenuObject.prototype.getContextMenuHideAllMode = function() {
	return this.contextHideAllMode;
}
/****************************************************************************************************************************************************/
/*								 	VISIBLE AREA								    */
/**
*   @desc: sets the area in which the menu can appear, if the area is not set, the menu will occupy all available visible space
*   @param: x1, x2 - int, leftmost and rightmost coordinates by x axis
*   @param: y1, y2 - int, topmost and bottommost coordinates by y axis
*   @type: public
*/
dhtmlXMenuObject.prototype.setVisibleArea = function(x1, x2, y1, y2) {
	this._isVisibleArea = true;
	this.menuX1 = x1;
	this.menuX2 = x2;
	this.menuY1 = y1;
	this.menuY2 = y2;
}
/****************************************************************************************************************************************************/
/*								 	TOOLTOPS								    */
// tooltips, added in 0.4
/**
*   @desc: sets tooltip for a menu item
*   @param: id - menu item's id
*   @param: tip - tooltip
*   @type: public
*/
dhtmlXMenuObject.prototype.setTooltip = function(id, tip) {
	id = this.idPrefix+id;
	if (!(this.itemPull[id] != null && this.idPull[id] != null)) return;
	this.idPull[id].title = (tip.length > 0 ? tip : null);
	this.itemPull[id]["tip"] = tip;
}
/**
*   @desc: returns tooltip of a menu item
*   @param: id - menu item's id
*   @type: public
*/
dhtmlXMenuObject.prototype.getTooltip = function(id) {
	if (this.itemPull[this.idPrefix+id] == null) return null;
	return this.itemPull[this.idPrefix+id]["tip"];
}
/****************************************************************************************************************************************************/
/*								 	HOTKEYS									    */
//#menu_hotkey:06062008#{
// hot-keys, added in 0.4
/**
*   @desc: sets menu hot-key (just text label)
*   @param: id - menu item's id
*   @param: hkey - hot-key text
*   @type: public
*/
dhtmlXMenuObject.prototype.setHotKey = function(id, hkey) {
	
	id = this.idPrefix+id;
	
	if (!(this.itemPull[id] != null && this.idPull[id] != null)) return;
	if (this.itemPull[id]["parent"] == this.idPrefix+this.topId && !this.context) return;
	if (this.itemPull[id]["complex"]) return;
	var t = this.itemPull[id]["type"];
	if (!(t == "item" || t == "checkbox" || t == "radio")) return;
	
	// retrieve obj
	var hkObj = null;
	try { if (this.idPull[id].childNodes[this._rtl?0:2].childNodes[0].className == "sub_item_hk") hkObj = this.idPull[id].childNodes[this._rtl?0:2].childNodes[0]; } catch(e){}
	
	if (hkey.length == 0) {
		// remove if exists
		this.itemPull[id]["hotkey_backup"] = this.itemPull[id]["hotkey"];
		this.itemPull[id]["hotkey"] = "";
		if (hkObj != null) hkObj.parentNode.removeChild(hkObj);
		
	} else {
		
		// add if needed or change
		this.itemPull[id]["hotkey"] = hkey;
		this.itemPull[id]["hotkey_backup"] = null;
		//
		if (hkObj == null) {
			hkObj = document.createElement("DIV");
			hkObj.className = "sub_item_hk";
			var item = this.idPull[id].childNodes[this._rtl?0:2];
			while (item.childNodes.length > 0) item.removeChild(item.childNodes[0]);
			item.appendChild(hkObj);
		}
		hkObj.innerHTML = hkey;

	}
}
/**
*   @desc: returns item's hot-key (just text label)
*   @param: id - menu item's id
*   @type: public
*/
dhtmlXMenuObject.prototype.getHotKey = function(id) {
	if (this.itemPull[this.idPrefix+id] == null) return null;
	return this.itemPull[this.idPrefix+id]["hotkey"];
}
/****************************************************************************************************************************************************/
/*								 	MISC									    */
//#}
/* set toplevel item selected */
dhtmlXMenuObject.prototype.setItemSelected = function(id) {
	if (this.itemPull[this.idPrefix+id] == null) return null;
	// console.log(this.itemPull[this.idPrefix+id]);
	
}
/**
*   @desc: set top level additional text (in case of usual menubar)
*   @param: text - text
*   @type: public
*/
dhtmlXMenuObject.prototype.setTopText = function(text) {
	if (this.context) return;
	if (this._topText == null) {
		this._topText = document.createElement("DIV");
		this._topText.className = "dhtmlxMenu_TopLevel_Text_"+(this._rtl?"left":(this._align=="left"?"right":"left"));
		this.base.appendChild(this._topText);
	}
	this._topText.innerHTML = text;
}
/**
*   @desc: set top level menu align
*   @param: align - left|right
*   @type: public
*/
dhtmlXMenuObject.prototype.setAlign = function(align) {
	if (this._align == align) return;
	if (align == "left" || align == "right") {
		// if (this.setRTL) this.setRTL(false);
		this._align = align;
		if (this.cont) this.cont.className = (this._align=="right"?"align_right":"align_left");
		if (this._topText != null) this._topText.className = "dhtmlxMenu_TopLevel_Text_"+(this._align=="left"?"right":"left");
	}
}
/**
*   @desc: set href to item, overwrite old if exists
*   @param: itemId
*   @param: href - url to open instead of onClik event handling
*   @param: target - target attribute
*   @type: public
*/
dhtmlXMenuObject.prototype.setHref = function(itemId, href, target) {
	if (this.itemPull[this.idPrefix+itemId] == null) return;
	this.itemPull[this.idPrefix+itemId]["href_link"] = href;
	if (target != null) this.itemPull[this.idPrefix+itemId]["href_target"] = target;
}
/**
*   @desc: clears item href and back item to default onClick behavior
*   @param: itemId
*   @type: public
*/
dhtmlXMenuObject.prototype.clearHref = function(itemId) {
	if (this.itemPull[this.idPrefix+itemId] == null) return;
	delete this.itemPull[this.idPrefix+itemId]["href_link"];
	delete this.itemPull[this.idPrefix+itemId]["href_target"];
}
/*
File [id="file"] -> Open [id="open"] -> Last Save [id="lastsave"]
getCircuit("lastsave") will return Array("file", "open", "lastsave");
*/
/**
*   @desc: return array with ids from topmost parent to chosen item
*   @param: id - chosen item id
*   @type: public
*/
dhtmlXMenuObject.prototype.getCircuit = function(id) {
	var parents = new Array(id);
	while (this.getParentId(id) != this.topId) {
		id = this.getParentId(id);
		parents[parents.length] = id;
	}
	return parents.reverse();
}
/* export to function */
/* WTF?
dhtmlXMenuObject.prototype.generateSQL = function() {
	var sql = "INSERT INTO `dhtmlxmenu_demo` (`itemId`, `itemParentId`, `itemOrder`, `itemText`, `itemType`, `itemEnabled`, `itemChecked`, `itemGroup`, `itemImage`, `itemImageDis`) VALUES ";
	var values = "";
	var q = 0;
	for (var a in this.itemPull) {
		values += (values.length>0?", ":"")+"('"+a.replace(this.idPrefix,"")+"',"+
						     "'"+(this.itemPull[a]["parent"]!=null?this.itemPull[a]["parent"].replace(this.idPrefix,""):"")+"',"+
						     "'"+(q++)+"',"+
						     "'"+this.itemPull[a]["title"]+"',"+
						     "'"+(this.itemPull[a]["type"]!="item"?this.itemPull[a]["type"]:"")+"',"+
						     "'"+(this.itemPull[a]["state"]=="enabled"?"1":"0")+"',"+
						     "'"+(this.itemPull[a]["checked"]!=null?(this.itemPull[a]["checked"]?"1":"0"):"0")+"',"+
						     "'"+(this.itemPull[a]["group"]!=null?this.itemPull[a]["group"]:"")+"',"+
						     "'"+this.itemPull[a]["imgen"]+"',"+
						     "'"+this.itemPull[a]["imgdis"]+"')";
	}
	return sql+values;
}
*/
//#menu_overflow:06062008#{
/****************************************************************************************************************************************************/
/*								 	OVERFLOW								    */
/* clear all selected subitems in polygon, implemented in 0.4 */
dhtmlXMenuObject.prototype._clearAllSelectedSubItemsInPolygon = function(polygon) {
	var subIds = this._getSubItemToDeselectByPolygon(polygon);
	// hide opened polygons and selected items
	for (var q=0; q<this._openedPolygons.length; q++) { if (this._openedPolygons[q] != polygon) { this._hidePolygon(this._openedPolygons[q]); } }
	for (var q=0; q<subIds.length; q++) { if (this.idPull[subIds[q]] != null) { if (this.itemPull[subIds[q]]["state"] == "enabled") { this.idPull[subIds[q]].className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_Item_Normal"; } } }
}
/* define normal/disabled arrows in polygon */
dhtmlXMenuObject.prototype._checkArrowsState = function(id) {
	var polygon = this.idPull["polygon_"+id];
	var arrowUp = this.idPull["arrowup_"+id];
	var arrowDown = this.idPull["arrowdown_"+id];
	if (polygon.scrollTop == 0) {
		arrowUp.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowUp_Disabled";
	} else {
		arrowUp.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowUp" + (arrowUp.over ? "_Over" : "");
	}
	if (polygon.scrollTop + polygon.offsetHeight < polygon.scrollHeight) {
		arrowDown.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowDown" + (arrowDown.over ? "_Over" : "");
	} else {
		arrowDown.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowDown_Disabled";
	}
}
/* add up-limit-arrow */
dhtmlXMenuObject.prototype._addUpArrow = function(id) {
	var main_self = this;
	var arrow = document.createElement("DIV");
	arrow.pId = this.idPrefix+id;
	arrow.id = "arrowup_"+this.idPrefix+id;
	arrow.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowUp";
	arrow.innerHTML = "<div class='dhtmlxMenu_"+this.skin+"_SubLevelArea_Arrow'><div class='dhtmlxMenu_SubLevelArea_Arrow_Icon'></div></div>";
	arrow.style.display = "none";
	arrow.over = false;
	arrow.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
	arrow.oncontextmenu = function(e) { e = e||event; e.returnValue = false; return false; }
	// actions
	arrow.onmouseover = function() {
		if (main_self.menuMode == "web") { window.clearTimeout(main_self.menuTimeoutHandler); }
		main_self._clearAllSelectedSubItemsInPolygon(this.pId);
		if (this.className == "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowUp_Disabled") return;
		this.className = "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowUp_Over";
		this.over = true;
		main_self._canScrollUp = true;
		main_self._doScrollUp(this.pId, true);
	}
	arrow.onmouseout = function() {
		if (main_self.menuMode == "web") {
			window.clearTimeout(main_self.menuTimeoutHandler);
			main_self.menuTimeoutHandler = window.setTimeout(function(){main_self._clearAndHide();}, main_self.menuTimeoutMsec, "JavaScript");
		}
		this.over = false;
		main_self._canScrollUp = false;
		if (this.className == "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowUp_Disabled") return;
		this.className = "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowUp";
		window.clearTimeout(main_self._scrollUpTM);
	}
	arrow.onclick = function(e) {
		e = e||event;
		e.returnValue = false;
		e.cancelBubble = true;
		return false;
	}
	//
	// var polygon = this.idPull["polygon_"+this.idPrefix+id];
	// polygon.insertBefore(arrow, polygon.childNodes[0]);
	document.body.insertBefore(arrow, document.body.firstChild);
	this.idPull[arrow.id] = arrow;
}
dhtmlXMenuObject.prototype._addDownArrow = function(id) {
	var main_self = this;
	var arrow = document.createElement("DIV");
	arrow.pId = this.idPrefix+id;
	arrow.id = "arrowdown_"+this.idPrefix+id;
	arrow.className = "dhtmlxMenu_"+this.skin+"_SubLevelArea_ArrowDown";
	arrow.innerHTML = "<div class='dhtmlxMenu_"+this.skin+"_SubLevelArea_Arrow'><div class='dhtmlxMenu_SubLevelArea_Arrow_Icon'></div></div>";
	arrow.style.display = "none";
	arrow.over = false;
	arrow.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
	arrow.oncontextmenu = function(e) { e = e||event; e.returnValue = false; return false; }
	// actions
	arrow.onmouseover = function() {
		if (main_self.menuMode == "web") { window.clearTimeout(main_self.menuTimeoutHandler); }
		main_self._clearAllSelectedSubItemsInPolygon(this.pId);
		if (this.className == "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowDown_Disabled") return;
		this.className = "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowDown_Over";
		this.over = true;
		main_self._canScrollDown = true;
		main_self._doScrollDown(this.pId, true);
	}
	arrow.onmouseout = function() {
		if (main_self.menuMode == "web") {
			window.clearTimeout(main_self.menuTimeoutHandler);
			main_self.menuTimeoutHandler = window.setTimeout(function(){main_self._clearAndHide();}, main_self.menuTimeoutMsec, "JavaScript");
		}
		this.over = false;
		main_self._canScrollDown = false;
		if (this.className == "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowDown_Disabled") return;
		this.className = "dhtmlxMenu_"+main_self.skin+"_SubLevelArea_ArrowDown";
		window.clearTimeout(main_self._scrollDownTM);
	}
	arrow.onclick = function(e) {
		e = e||event;
		e.returnValue = false;
		e.cancelBubble = true;
		return false;
	}
	document.body.insertBefore(arrow, document.body.firstChild);
	this.idPull[arrow.id] = arrow;
}
dhtmlXMenuObject.prototype._removeUpArrow = function(id) {
	var fullId = "arrowup_"+this.idPrefix+id;
	this._removeArrow(fullId);
}
dhtmlXMenuObject.prototype._removeDownArrow = function(id) {
	var fullId = "arrowdown_"+this.idPrefix+id;
	this._removeArrow(fullId);
}
dhtmlXMenuObject.prototype._removeArrow = function(fullId) {
	var arrow = this.idPull[fullId];
	arrow.onselectstart = null;
	arrow.oncontextmenu = null;
	arrow.onmouseover = null;
	arrow.onmouseout = null;
	arrow.onclick = null;
	if (arrow.parentNode) arrow.parentNode.removeChild(arrow);
	arrow = null;
	this.idPull[fullId] = null;
	try { delete this.idPull[fullId]; } catch(e) {}
}
dhtmlXMenuObject.prototype._isArrowExists = function(id) {
	if (this.idPull["arrowup_"+id] != null && this.idPull["arrowdown_"+id] != null) return true;
	return false;
}
/* scroll down */
dhtmlXMenuObject.prototype._doScrollUp = function(id, checkArrows) {
	var polygon = this.idPull["polygon_"+id];
	if (this._canScrollUp && polygon.scrollTop > 0) {
		var theEnd = false;
		var nextScrollTop = polygon.scrollTop - this._scrollUpTMStep;
		if (nextScrollTop < 0) {
			theEnd = true;
			nextScrollTop = 0;
		}
		polygon.scrollTop = nextScrollTop;
		if (!theEnd) {
			var that = this;
			this._scrollUpTM = window.setTimeout(function() { that._doScrollUp(id, false); }, this._scrollUpTMTime);
		}
	} else {
		this._canScrollUp = false;
		this._checkArrowsState(id);
	}
	if (checkArrows) {
		this._checkArrowsState(id);
	}
}
dhtmlXMenuObject.prototype._doScrollDown = function(id, checkArrows) {
	var polygon = this.idPull["polygon_"+id];
	if (this._canScrollDown && polygon.scrollTop + polygon.offsetHeight <= polygon.scrollHeight) {
		var theEnd = false;
		var nextScrollTop = polygon.scrollTop + this._scrollDownTMStep;
		if (nextScrollTop + polygon.offsetHeight > polygon.scollHeight) {
			theEnd = true;
			nextScrollTop = polygon.scollHeight - polygon.offsetHeight;
		}
		polygon.scrollTop = nextScrollTop;
		if (!theEnd) {
			var that = this;
			this._scrollDownTM = window.setTimeout(function() { that._doScrollDown(id, false); }, this._scrollDownTMTime);
		}
	} else {
		this._canScrollDown
		this._checkArrowsState(id);
	}
	if (checkArrows) {
		this._checkArrowsState(id);
	}
}
//
dhtmlXMenuObject.prototype._countPolygonItems = function(id) {
	var count = 0;
	for (var a in this.itemPull) {
		var par = this.itemPull[a]["parent"];
		var tp = this.itemPull[a]["type"];
		if (par == this.idPrefix+id && (tp == "item" || tp == "radio" || tp == "checkbox")) { count++; }
	}
	return count;
}
/* limit maximum items on single polygon, default - 0 = no limit */
/**
*   @desc: limits the maximum number of visible items in polygons
*   @param: itemsNum - count of the maximum number of visible items
*   @type: public
*/
dhtmlXMenuObject.prototype.setOverflowHeight = function(itemsNum) {
	
	// set auto overflow mode
	if (itemsNum === "auto") {
		this.limit = 0;
		this.autoOverflow = true;
		return;
	}
	
	// no existing limitation, now new limitation
	if (this.limit == 0 && itemsNum <= 0) return;
	
	// hide menu to prevent visible changes
	this._clearAndHide();
	
	// redefine existing limitation, arrows will added automatically with showPlygon
	if (this.limit >= 0 && itemsNum > 0) {
		this.limit = itemsNum;
		return;
	}
	
	// remove existing limitation
	if (this.limit > 0 && itemsNum <= 0) {
		for (var a in this.itemPull) {
			if (this._isArrowExists(a)) {
				var b = String(a).replace(this.idPrefix, "");
				this._removeUpArrow(b);
				this._removeDownArrow(b);
				// remove polygon's height
				this.idPull["polygon_"+a].style.height = "";
			}
		}
		this.limit = 0;
		return;
	}
}
//#}
/****************************************************************************************************************************************************/
/*								 	RADIOBUTTONS								    */
//#menu_radio:06062008{
dhtmlXMenuObject.prototype._getRadioImgObj = function(id) {
	try { var imgObj = this.idPull[this.idPrefix+id].childNodes[(this._rtl?2:0)].childNodes[0] } catch(e) { var imgObj = null; }
	return imgObj;
}
dhtmlXMenuObject.prototype._setRadioState = function(id, state) {
	// if (this.itemPull[this.idPrefix+id]["state"] != "enabled") return;
	var imgObj = this._getRadioImgObj(id);
	if (imgObj != null) {
		// fix, added in 0.4
		var rObj = this.itemPull[this.idPrefix+id];
		rObj["checked"] = state;
		rObj["imgen"] = "rdbt_"+(rObj["checked"]?"1":"0");
		rObj["imgdis"] = rObj["imgen"];
		imgObj.className = "sub_icon "+rObj["imgen"];
	}
}
dhtmlXMenuObject.prototype._radioOnClickHandler = function(id, type, casState) {
	if (type.charAt(1)=="d" || this.itemPull[this.idPrefix+id]["group"]==null) return;
	// deselect all from the same group
	var group = this.itemPull[this.idPrefix+id]["group"];
	if (this.checkEvent("onRadioClick")) {
		if (this.callEvent("onRadioClick", [group, this.getRadioChecked(group), id, this.contextMenuZoneId, casState])) {
			this.setRadioChecked(group, id);
		}
	} else {
		this.setRadioChecked(group, id);
	}
	// call onClick if exists
	if (this.checkEvent("onClick")) this.callEvent("onClick", [id]);
}
/**
*   @desc: returns a checked radio button in the group
*   @param: group - radio button group
*   @type: public
*/
dhtmlXMenuObject.prototype.getRadioChecked = function(group) {
	var id = null;
	for (var q=0; q<this.radio[group].length; q++) {
		var itemId = this.radio[group][q].replace(this.idPrefix, "");
		var imgObj = this._getRadioImgObj(itemId);
		if (imgObj != null) {
			var checked = (imgObj.className).match(/rdbt_1$/gi);
			if (checked != null) id = itemId;
		}
	}
	return id;
}
/**
*   @desc: checks a radio button inside the group
*   @param: group - radio button group
*   @param: id - radio button's id
*   @type: public
*/
dhtmlXMenuObject.prototype.setRadioChecked = function(group, id) {
	if (this.radio[group] == null) return;
	for (var q=0; q<this.radio[group].length; q++) {
		var itemId = this.radio[group][q].replace(this.idPrefix, "");
		this._setRadioState(itemId, (itemId==id));
	}
}
/**
*   @desc: adds a new radio button, sibling|child mode
*   @param: mode - (string) sibling|child
*   @param: nextToId - the item after which the radio button will be added in the "sibling" mode or parent item's id in the "child" mode
*   @param: pos - the item's position in the child mode (null for sibling)
*   @param: itemId - id of a new radio button
*   @param: itemText - text of a new radio button
*   @param: group - radiogroup's id
*   @param: state - checked|unchecked
*   @param: disabled - enabled|disabled
*   @type: public
*/
dhtmlXMenuObject.prototype.addRadioButton = function(mode, nextToId, pos, itemId, itemText, group, state, disabled) {
	// radiobutton
	/*
	if (this.itemPull[this.idPrefix+nextToId] == null) return;
	if (this.itemPull[this.idPrefix+nextToId]["parent"] == this.idPrefix+this.topId) return;
	*/
	if (this.context && nextToId == this.topId) {
		// adding radiobutton as first element to context menu
		// do nothing
	} else {
		if (this.itemPull[this.idPrefix+nextToId] == null) return;
		if (mode == "child" && this.itemPull[this.idPrefix+nextToId]["type"] != "item") return;
		// if (this.itemPull[this.idPrefix+nextToId]["parent"] == this.idPrefix+this.topId && !this.context) return;
	}
	
	//
	//
	var id = this.idPrefix+(itemId!=null?itemId:this._genStr(24));
	var img = "rdbt_"+(state?"1":"0");
	var imgDis = img;
	//
	if (mode == "sibling") {
		var parentId = this.idPrefix+this.getParentId(nextToId);
		this._addItemIntoGlobalStrorage(id, parentId, itemText, "radio", disabled, img, imgDis);
		this._renderSublevelItem(id, this.getItemPosition(nextToId));
	} else {
		var parentId = this.idPrefix+nextToId;
		this._addItemIntoGlobalStrorage(id, parentId, itemText, "radio", disabled, img, imgDis);
		if (this.idPull["polygon_"+parentId] == null) { this._renderSublevelPolygon(parentId, parentId); }
		this._renderSublevelItem(id, pos-1);
		this._redefineComplexState(parentId);
	}
	//
	var gr = (group!=null?group:this._genStr(24));
	this.itemPull[id]["group"] = gr;
	//
	if (this.radio[gr]==null) { this.radio[gr] = new Array(); }
	this.radio[gr][this.radio[gr].length] = id;
	//
	if (state == true) this.setRadioChecked(gr, String(id).replace(this.idPrefix, ""));
}
//#}
/****************************************************************************************************************************************************/
/*								 	CHECKBOXES								    */
//#menu_checks:06062008{
dhtmlXMenuObject.prototype._getCheckboxState = function(id) {
	if (this.itemPull[this.idPrefix+id] == null) return null;
	return this.itemPull[this.idPrefix+id]["checked"];
}
dhtmlXMenuObject.prototype._setCheckboxState = function(id, state) {
	if (this.itemPull[this.idPrefix+id] == null) return;
	this.itemPull[this.idPrefix+id]["checked"] = state;
}
dhtmlXMenuObject.prototype._updateCheckboxImage = function(id) {
	if (this.idPull[this.idPrefix+id] == null) return;
	this.itemPull[this.idPrefix+id]["imgen"] = "chbx_"+(this._getCheckboxState(id)?"1":"0");
	this.itemPull[this.idPrefix+id]["imgdis"] = this.itemPull[this.idPrefix+id]["imgen"];
	try { this.idPull[this.idPrefix+id].childNodes[(this._rtl?2:0)].childNodes[0].className = "sub_icon "+this.itemPull[this.idPrefix+id]["imgen"]; } catch(e){}
}
dhtmlXMenuObject.prototype._checkboxOnClickHandler = function(id, type, casState) {
	if (type.charAt(1)=="d") return;
	if (this.itemPull[this.idPrefix+id] == null) return;
	var state = this._getCheckboxState(id);
	if (this.checkEvent("onCheckboxClick")) {
		if (this.callEvent("onCheckboxClick", [id, state, this.contextMenuZoneId, casState])) {
			this.setCheckboxState(id, !state);
		}
	} else {
		this.setCheckboxState(id, !state);
	}
	// call onClick if exists
	if (this.checkEvent("onClick")) this.callEvent("onClick", [id]);
}
/**
*   @desc: sets checkbox's state
*   @param: id - the item
*   @param: state - a new state (true|false)
*   @type: public
*/
dhtmlXMenuObject.prototype.setCheckboxState = function(id, state) {
	this._setCheckboxState(id, state);
	this._updateCheckboxImage(id);
}
/**
*   @desc: returns current checkbox's state
*   @param: id - the item
*   @type: public
*/
dhtmlXMenuObject.prototype.getCheckboxState = function(id) {
	return this._getCheckboxState(id);
}
/**
*   @desc: adds a new checkbox, sibling|child mode
*   @param: mode - (string) sibling|child
*   @param: nextToId - the item after which the checkbox will be added in the "sibling" mode or parent item's id in the "child" mode
*   @param: pos - item's position in the child mode (null for sibling)
*   @param: itemId - id of a new checkbox
*   @param: itemText - text of a new checkbox
*   @param: state - checked|unchecked
*   @param: disabled - enabled|disabled
*   @type: public
*/
dhtmlXMenuObject.prototype.addCheckbox = function(mode, nextToId, pos, itemId, itemText, state, disabled) {
	// checks
	if (this.context && nextToId == this.topId) {
		// adding checkbox as first element to context menu
		// do nothing
	} else {
		if (this.itemPull[this.idPrefix+nextToId] == null) return;
		if (mode == "child" && this.itemPull[this.idPrefix+nextToId]["type"] != "item") return;
		// if (this.itemPull[this.idPrefix+nextToId]["parent"] == this.idPrefix+this.topId && !this.context) return;
	}
	//
	var img = "chbx_"+(state?"1":"0");
	var imgDis = img;
	//
	
	if (mode == "sibling") {
		
		var id = this.idPrefix+(itemId!=null?itemId:this._genStr(24));
		var parentId = this.idPrefix+this.getParentId(nextToId);
		this._addItemIntoGlobalStrorage(id, parentId, itemText, "checkbox", disabled, img, imgDis);
		this.itemPull[id]["checked"] = state;
		this._renderSublevelItem(id, this.getItemPosition(nextToId));
	} else {
		
		var id = this.idPrefix+(itemId!=null?itemId:this._genStr(24));
		var parentId = this.idPrefix+nextToId;
		this._addItemIntoGlobalStrorage(id, parentId, itemText, "checkbox", disabled, img, imgDis);
		this.itemPull[id]["checked"] = state;
		if (this.idPull["polygon_"+parentId] == null) { this._renderSublevelPolygon(parentId, parentId); }
		this._renderSublevelItem(id, pos-1);
		this._redefineComplexState(parentId);
	}
}
//#}
/****************************************************************************************************************************************************/
/*								 	SERIALIZE								    */
dhtmlXMenuObject.prototype._readLevel = function(parentId) {
	var xml = "";
	for (var a in this.itemPull) {
		if (this.itemPull[a]["parent"] == parentId) {
			var imgEn = "";
			var imgDis = "";
			var hotKey = "";
			var itemId = String(this.itemPull[a]["id"]).replace(this.idPrefix,"");
			var itemType = "";
			var itemText = (this.itemPull[a]["title"]!=""?' text="'+this.itemPull[a]["title"]+'"':"");
			var itemState = "";
			if (this.itemPull[a]["type"] == "item") {
				if (this.itemPull[a]["imgen"] != "") imgEn = ' img="'+this.itemPull[a]["imgen"]+'"';
				if (this.itemPull[a]["imgdis"] != "") imgDis = ' imgdis="'+this.itemPull[a]["imgdis"]+'"';
				if (this.itemPull[a]["hotkey"] != "") hotKey = '<hotkey>'+this.itemPull[a]["hotkey"]+'</hotkey>';
			}
			if (this.itemPull[a]["type"] == "separator") {
				itemType = ' type="separator"';
			} else {
				if (this.itemPull[a]["state"] == "disabled") itemState = ' enabled="false"';
			}
			if (this.itemPull[a]["type"] == "checkbox") {
				itemType = ' type="checkbox"'+(this.itemPull[a]["checked"]?' checked="true"':"");
			}
			if (this.itemPull[a]["type"] == "radio") {
				itemType = ' type="radio" group="'+this.itemPull[a]["group"]+'" '+(this.itemPull[a]["checked"]?' checked="true"':"");
			}
			xml += "<item id='"+itemId+"'"+itemText+itemType+imgEn+imgDis+itemState+">";
			xml += hotKey;
			if (this.itemPull[a]["complex"]) xml += this._readLevel(a);
			xml += "</item>";
		}
	}
	return xml;
}
/**
*   @desc: serialize menu to xml
*   @type: public
*/
dhtmlXMenuObject.prototype.serialize = function() {
	var xml = "<menu>"+this._readLevel(this.idPrefix+this.topId)+"</menu>";
	return xml;
}
/****************************************************************************************************************************************************/
