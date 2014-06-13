/*==================================================
 *  Graphics Utility Functions and Constants
 *==================================================
 */

Timeline.Graphics = new Object();
Timeline.Graphics.pngIsTranslucent = (!Timeline.Platform.browser.isIE) || (Timeline.Platform.browser.majorVersion > 6);

Timeline.Graphics.createTranslucentImage = function(doc, url, verticalAlign) {
    var elmt;
    if (Timeline.Graphics.pngIsTranslucent) {
        elmt = doc.createElement("img");
        elmt.setAttribute("src", url);
    } else {
        elmt = doc.createElement("img");
        elmt.style.display = "inline";
        elmt.style.width = "1px";  // just so that IE will calculate the size property
        elmt.style.height = "1px";
        elmt.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + url +"', sizingMethod='image')";
    }
    elmt.style.verticalAlign = (verticalAlign != null) ? verticalAlign : "middle";
    return elmt;
};

Timeline.Graphics.setOpacity = function(elmt, opacity) {
    if (Timeline.Platform.browser.isIE) {
        elmt.style.filter = "progid:DXImageTransform.Microsoft.Alpha(Style=0,Opacity=" + opacity + ")";
    } else {
        var o = (opacity / 100).toString();
        elmt.style.opacity = o;
        elmt.style.MozOpacity = o;
    }
};

Timeline.Graphics._bubbleMargins = {
    top:      33,
    bottom:   42,
    left:     33,
    right:    40
}

// pixels from boundary of the whole bubble div to the tip of the arrow
Timeline.Graphics._arrowOffsets = { 
    top:      0,
    bottom:   9,
    left:     1,
    right:    8
}

Timeline.Graphics._bubblePadding = 15;
Timeline.Graphics._bubblePointOffset = 6;
Timeline.Graphics._halfArrowWidth = 18;

Timeline.Graphics.createBubbleForPoint = function(doc, pageX, pageY, contentWidth, contentHeight) {
    function getWindowDims() {
        if (typeof window.innerWidth == 'number') {
	    return { w:window.innerWidth, h:window.innerHeight }; // Non-IE
	} else if (document.documentElement && document.documentElement.clientWidth) {
	    return { // IE6+, in "standards compliant mode"
		w:document.documentElement.clientWidth,
		h:document.documentElement.clientHeight
	    };
	} else if (document.body && document.body.clientWidth) {
	    return { // IE 4 compatible
		w:document.body.clientWidth,
		h:document.body.clientHeight
	    };
	}
    }

    var bubble = {
        _closed:    false,
        _doc:       doc,
        close:      function() { 
            if (!this._closed) {
                this._doc.body.removeChild(this._div);
                this._doc = null;
                this._div = null;
                this._content = null;
                this._closed = true;
            }
        }
    };

    var dims = getWindowDims();
    var docWidth = dims.w;
    var docHeight = dims.h;

    var margins = Timeline.Graphics._bubbleMargins;
    contentWidth = parseInt(contentWidth, 10); // harden against bad input bugs
    contentHeight = parseInt(contentHeight, 10); // getting numbers-as-strings
    var bubbleWidth = margins.left + contentWidth + margins.right;
    var bubbleHeight = margins.top + contentHeight + margins.bottom;

    var pngIsTranslucent = Timeline.Graphics.pngIsTranslucent;
    var urlPrefix = Timeline.urlPrefix;
    
    var setImg = function(elmt, url, width, height) {
        elmt.style.position = "absolute";
        elmt.style.width = width + "px";
        elmt.style.height = height + "px";
        if (pngIsTranslucent) {
            elmt.style.background = "url(" + url + ")";
        } else {
            elmt.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + url +"', sizingMethod='crop')";
        }
    }
    var div = doc.createElement("div");
    div.style.width = bubbleWidth + "px";
    div.style.height = bubbleHeight + "px";
    div.style.position = "absolute";
    div.style.zIndex = 1000;
    bubble._div = div;
    
    var divInner = doc.createElement("div");
    divInner.style.width = "100%";
    divInner.style.height = "100%";
    divInner.style.position = "relative";
    div.appendChild(divInner);
    
    var createImg = function(url, left, top, width, height) {
        var divImg = doc.createElement("div");
        divImg.style.left = left + "px";
        divImg.style.top = top + "px";
        setImg(divImg, url, width, height);
        divInner.appendChild(divImg);
    }
    
    createImg(urlPrefix + "images/bubble-top-left.png", 0, 0, margins.left, margins.top);
    createImg(urlPrefix + "images/bubble-top.png", margins.left, 0, contentWidth, margins.top);
    createImg(urlPrefix + "images/bubble-top-right.png", margins.left + contentWidth, 0, margins.right, margins.top);
    
    createImg(urlPrefix + "images/bubble-left.png", 0, margins.top, margins.left, contentHeight);
    createImg(urlPrefix + "images/bubble-right.png", margins.left + contentWidth, margins.top, margins.right, contentHeight);
    
    createImg(urlPrefix + "images/bubble-bottom-left.png", 0, margins.top + contentHeight, margins.left, margins.bottom);
    createImg(urlPrefix + "images/bubble-bottom.png", margins.left, margins.top + contentHeight, contentWidth, margins.bottom);
    createImg(urlPrefix + "images/bubble-bottom-right.png", margins.left + contentWidth, margins.top + contentHeight, margins.right, margins.bottom);
    
    var divClose = doc.createElement("div");
    divClose.style.left = (bubbleWidth - margins.right + Timeline.Graphics._bubblePadding - 16 - 2) + "px";
    divClose.style.top = (margins.top - Timeline.Graphics._bubblePadding + 1) + "px";
    divClose.style.cursor = "pointer";
    setImg(divClose, urlPrefix + "images/close-button.png", 16, 16);
    Timeline.DOM.registerEventWithObject(divClose, "click", bubble, bubble.close);
    divInner.appendChild(divClose);
        
    var divContent = doc.createElement("div");
    divContent.style.position = "absolute";
    divContent.style.left = margins.left + "px";
    divContent.style.top = margins.top + "px";
    divContent.style.width = contentWidth + "px";
    divContent.style.height = contentHeight + "px";
    divContent.style.overflow = "auto";
    divContent.style.background = "white";
    divInner.appendChild(divContent);
    bubble.content = divContent;
    
    (function() {
        if (pageX - Timeline.Graphics._halfArrowWidth - Timeline.Graphics._bubblePadding > 0 &&
            pageX + Timeline.Graphics._halfArrowWidth + Timeline.Graphics._bubblePadding < docWidth) {
            
            var left = pageX - Math.round(contentWidth / 2) - margins.left;
            left = pageX < (docWidth / 2) ?
                Math.max(left, -(margins.left - Timeline.Graphics._bubblePadding)) : 
                Math.min(left, docWidth + (margins.right - Timeline.Graphics._bubblePadding) - bubbleWidth);
                
            if (pageY - Timeline.Graphics._bubblePointOffset - bubbleHeight > 0) { // top
                var divImg = doc.createElement("div");
                
                divImg.style.left = (pageX - Timeline.Graphics._halfArrowWidth - left) + "px";
                divImg.style.top = (margins.top + contentHeight) + "px";
                setImg(divImg, urlPrefix + "images/bubble-bottom-arrow.png", 37, margins.bottom);
                divInner.appendChild(divImg);
                
                div.style.left = left + "px";
                div.style.top = (pageY - Timeline.Graphics._bubblePointOffset - bubbleHeight + 
                    Timeline.Graphics._arrowOffsets.bottom) + "px";
                
                return;
            } else if (pageY + Timeline.Graphics._bubblePointOffset + bubbleHeight < docHeight) { // bottom
                var divImg = doc.createElement("div");
                
                divImg.style.left = (pageX - Timeline.Graphics._halfArrowWidth - left) + "px";
                divImg.style.top = "0px";
                setImg(divImg, urlPrefix + "images/bubble-top-arrow.png", 37, margins.top);
                divInner.appendChild(divImg);
                
                div.style.left = left + "px";
                div.style.top = (pageY + Timeline.Graphics._bubblePointOffset - 
                    Timeline.Graphics._arrowOffsets.top) + "px";
                
                return;
            }
        }
        
        var top = pageY - Math.round(contentHeight / 2) - margins.top;
        top = pageY < (docHeight / 2) ?
            Math.max(top, -(margins.top - Timeline.Graphics._bubblePadding)) : 
            Math.min(top, docHeight + (margins.bottom - Timeline.Graphics._bubblePadding) - bubbleHeight);
                
        if (pageX - Timeline.Graphics._bubblePointOffset - bubbleWidth > 0) { // left
            var divImg = doc.createElement("div");
            
            divImg.style.left = (margins.left + contentWidth) + "px";
            divImg.style.top = (pageY - Timeline.Graphics._halfArrowWidth - top) + "px";
            setImg(divImg, urlPrefix + "images/bubble-right-arrow.png", margins.right, 37);
            divInner.appendChild(divImg);
            
            div.style.left = (pageX - Timeline.Graphics._bubblePointOffset - bubbleWidth +
                Timeline.Graphics._arrowOffsets.right) + "px";
            div.style.top = top + "px";
        } else { // right
            var divImg = doc.createElement("div");
            
            divImg.style.left = "0px";
            divImg.style.top = (pageY - Timeline.Graphics._halfArrowWidth - top) + "px";
            setImg(divImg, urlPrefix + "images/bubble-left-arrow.png", margins.left, 37);
            divInner.appendChild(divImg);
            
            div.style.left = (pageX + Timeline.Graphics._bubblePointOffset - 
                Timeline.Graphics._arrowOffsets.left) + "px";
            div.style.top = top + "px";
        }
    })();
    
    doc.body.appendChild(div);
    
    return bubble;
};

Timeline.Graphics.createMessageBubble = function(doc) {
    var containerDiv = doc.createElement("div");
    if (Timeline.Graphics.pngIsTranslucent) {
        var topDiv = doc.createElement("div");
        topDiv.style.height = "33px";
        topDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-top-left.png) top left no-repeat";
        topDiv.style.paddingLeft = "44px";
        containerDiv.appendChild(topDiv);
        
        var topRightDiv = doc.createElement("div");
        topRightDiv.style.height = "33px";
        topRightDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-top-right.png) top right no-repeat";
        topDiv.appendChild(topRightDiv);
        
        var middleDiv = doc.createElement("div");
        middleDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-left.png) top left repeat-y";
        middleDiv.style.paddingLeft = "44px";
        containerDiv.appendChild(middleDiv);
        
        var middleRightDiv = doc.createElement("div");
        middleRightDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-right.png) top right repeat-y";
        middleRightDiv.style.paddingRight = "44px";
        middleDiv.appendChild(middleRightDiv);
        
        var contentDiv = doc.createElement("div");
        middleRightDiv.appendChild(contentDiv);
        
        var bottomDiv = doc.createElement("div");
        bottomDiv.style.height = "55px";
        bottomDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-bottom-left.png) bottom left no-repeat";
        bottomDiv.style.paddingLeft = "44px";
        containerDiv.appendChild(bottomDiv);
        
        var bottomRightDiv = doc.createElement("div");
        bottomRightDiv.style.height = "55px";
        bottomRightDiv.style.background = "url(" + Timeline.urlPrefix + "images/message-bottom-right.png) bottom right no-repeat";
        bottomDiv.appendChild(bottomRightDiv);
    } else {
        containerDiv.style.border = "2px solid #7777AA";
        containerDiv.style.padding = "20px";
        containerDiv.style.background = "white";
        Timeline.Graphics.setOpacity(containerDiv, 90);
        
        var contentDiv = doc.createElement("div");
        containerDiv.appendChild(contentDiv);
    }
    
    return {
        containerDiv:   containerDiv,
        contentDiv:     contentDiv
    };
};

Timeline.Graphics.createAnimation = function(f, from, to, duration) {
    return new Timeline.Graphics._Animation(f, from, to, duration);
};

Timeline.Graphics._Animation = function(f, from, to, duration) {
    this.f = f;
    
    this.from = from;
    this.to = to;
    this.current = from;
    
    this.duration = duration;
    this.start = new Date().getTime();
    this.timePassed = 0;
};

Timeline.Graphics._Animation.prototype.run = function() {
    var a = this;
    window.setTimeout(function() { a.step(); }, 100);
};

Timeline.Graphics._Animation.prototype.step = function() {
    this.timePassed += 100;
    
    var timePassedFraction = this.timePassed / this.duration;
    var parameterFraction = -Math.cos(timePassedFraction * Math.PI) / 2 + 0.5;
    var current = parameterFraction * (this.to - this.from) + this.from;
    
    try {
        this.f(current, current - this.current);
    } catch (e) {
    }
    this.current = current;
    
    if (this.timePassed < this.duration) {
        this.run();
    }
};
