/*==================================================
 *  Thumbnail Event Painter
 *==================================================
 */

Timeline.ThumbnailEventPainter = function(params) {
    this._params = params;
    this._theme = params.theme;
    
    // all in pixels
    this._thumbnailWidth = params.thumbnailWidth;
    this._thumbnailHeight = params.thumbnailHeight;
    this._labelWidth = params.labelWidth;
    this._trackHeight = params.trackHeight;
    this._trackOffset = params.trackOffset;
    
    this._filterMatcher = null;
    this._highlightMatcher = null;
};

Timeline.ThumbnailEventPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._layout = ("layout" in this._params) ? this._params.layout : 
        new Timeline.ThumbnailMultiTrackBasedLayout({
            thumbnailWidth:     this._thumbnailWidth,
            thumbnailHeight:    this._thumbnailHeight,
            labelWidth:         this._labelWidth,
            trackHeight:        this._trackHeight,
            ether:              band.getEther(),
            eventSource:        band.getEventSource()
        });
    
    this._layout.initialize(timeline);
    
    this._eventLayer = null;
    this._highlightLayer = null;
};

Timeline.ThumbnailEventPainter.prototype.getLayout = function() {
    return this._layout;
};

Timeline.ThumbnailEventPainter.prototype.setLayout = function(layout) {
    this._layout = layout;
};

Timeline.ThumbnailEventPainter.prototype.getFilterMatcher = function() {
    return this._filterMatcher;
};

Timeline.ThumbnailEventPainter.prototype.setFilterMatcher = function(filterMatcher) {
    this._filterMatcher = filterMatcher;
};

Timeline.ThumbnailEventPainter.prototype.getHighlightMatcher = function() {
    return this._highlightMatcher;
};

Timeline.ThumbnailEventPainter.prototype.setHighlightMatcher = function(highlightMatcher) {
    this._highlightMatcher = highlightMatcher;
};

Timeline.ThumbnailEventPainter.prototype.paint = function() {
    var eventSource = this._band.getEventSource();
    if (eventSource == null) {
        return;
    }
    
    if (this._highlightLayer != null) {
        this._band.removeLayerDiv(this._highlightLayer);
    }
    this._highlightLayer = this._band.createLayerDiv(105);
    this._highlightLayer.setAttribute("name", "event-highlights");
    this._highlightLayer.style.display = "none";
    
    if (this._eventLayer != null) {
        this._band.removeLayerDiv(this._eventLayer);
    }
    this._eventLayer = this._band.createLayerDiv(110);
    this._eventLayer.setAttribute("name", "events");
    this._eventLayer.style.display = "none";
    
    var minDate = this._band.getMinDate();
    var maxDate = this._band.getMaxDate();
    
    var doc = this._timeline.getDocument();
    
    var p = this;
    var eventLayer = this._eventLayer;
    var highlightLayer = this._highlightLayer;
    
    var theme = this._theme;
    var textColor = theme.event.label.outsideColor;
    
    var createEventDiv = function(evt, highlightIndex) {
        var date = evt.getStart();
        var thumbnail = evt.getProperty("icon");
        
        var pixel = Math.round(p._band.dateToPixelOffset(date));
        var trackIndex = p._layout.getTrack(evt);
        var trackOffset = p._trackOffset + trackIndex * p._trackHeight;
            
        var div = doc.createElement("div");
        div.style.position = "absolute";
        div.style.overflow = "hidden";
        div.style.color = textColor;
        
        div.style.left = pixel + "px";
        div.style.top = trackOffset + "px";
        div.style.width = p._thumbnailWidth + p._labelWidth;
        div.style.height = p._thumbnailHeight;
        
        var img = doc.createElement("img");
        img.src = thumbnail;
        img.style.verticalAlign = "text-top";
        img.style.cssFloat = "left";
        div.appendChild(img);
        
        /*
        var divLabel = document.createElement("div");
        divLabel.style.height = p._trackHeight;
        divLabel.style.overflow = "hidden";
        divLabel.appendChild(doc.createTextNode(evt.getText()));
        div.appendChild(divLabel);
        */
        
        var span = doc.createElement("span");
        span.appendChild(doc.createTextNode(evt.getText()));
        div.appendChild(span);
        
        div.style.cursor = "pointer";
        Timeline.DOM.registerEvent(div, "mousedown", function(elmt, domEvt, target) {
            p._onClickInstantEvent(img, domEvt, evt);
        });
            
        eventLayer.appendChild(div);
        
        if (highlightIndex >= 0) {
            // commenting code to change background color of event group filters
	          //span.style.background = 
	          //    theme.event.highlightColors[Math.min(highlightIndex, theme.event.highlightColors.length - 1)];
						// added code to change color on text of event group filters
						span.style.color = 
                theme.event.highlightColors[Math.min(highlightIndex, theme.event.highlightColors.length - 1)];
        }
    };
    
    var filterMatcher = (this._filterMatcher != null) ? 
        this._filterMatcher :
        function(evt) { return true; };
    var highlightMatcher = (this._highlightMatcher != null) ? 
        this._highlightMatcher :
        function(evt) { return -1; };
    
    var iterator = eventSource.getEventIterator(minDate, maxDate);
    while (iterator.hasNext()) {
        var evt = iterator.next();
        if (filterMatcher(evt)) {
            createEventDiv(evt, highlightMatcher(evt));
        }
    }
    
    this._highlightLayer.style.display = "block";
    this._eventLayer.style.display = "block";
};

Timeline.ThumbnailEventPainter.prototype.softPaint = function() {
};

Timeline.ThumbnailEventPainter.prototype._onClickInstantEvent = function(icon, domEvt, evt) {
    domEvt.cancelBubble = true;
    
    var c = Timeline.DOM.getPageCoordinates(icon);
    this._showBubble(
        c.left + Math.ceil(icon.offsetWidth / 2), 
        c.top + Math.ceil(icon.offsetHeight / 2),
        evt
    );
};

Timeline.ThumbnailEventPainter.prototype._onClickDurationEvent = function(domEvt, evt, target) {
    domEvt.cancelBubble = true;
    if ("pageX" in domEvt) {
        var x = domEvt.pageX;
        var y = domEvt.pageY;
    } else {
        var c = Timeline.DOM.getPageCoordinates(target);
        var x = domEvt.offsetX + c.left;
        var y = domEvt.offsetY + c.top;
    }
    this._showBubble(x, y, evt);
};

Timeline.ThumbnailEventPainter.prototype._showBubble = function(x, y, evt) {
    var div = this._band.openBubbleForPoint(
        x, y,
        this._theme.event.bubble.width,
        this._theme.event.bubble.height
    );
    
    var doc = this._timeline.getDocument();
    
    var title = evt.getText();
    var link = evt.getLink();
    var image = evt.getImage();
    
    if (image != null) {
        var img = doc.createElement("img");
        img.src = image;
        
        this._theme.event.bubble.imageStyler(img);
        div.appendChild(img);
    }
    
    var divTitle = doc.createElement("div");
    var textTitle = doc.createTextNode(title);
    if (link != null) {
        var a = doc.createElement("a");
        a.href = link;
        a.appendChild(textTitle);
        divTitle.appendChild(a);
    } else {
        divTitle.appendChild(textTitle);
    }
    this._theme.event.bubble.titleStyler(divTitle);
    div.appendChild(divTitle);
    
    var divBody = doc.createElement("div");
    evt.fillDescription(divBody);
    this._theme.event.bubble.bodyStyler(divBody);
    div.appendChild(divBody);

		// MIQ -- comment this line to hide datetime at the end of Bubble
    //var divTime = doc.createElement("div");
    //evt.fillTime(divTime, this._band.getLabeller());
    //this._theme.event.bubble.timeStyler(divTime);
    //div.appendChild(divTime);
    
    var divWiki = doc.createElement("div");
    evt.fillWikiInfo(divWiki);
    this._theme.event.bubble.wikiStyler(divWiki);
    div.appendChild(divWiki);
};