/*==================================================
 *  Sorted Array
 *==================================================
 */

Timeline.SortedArray = function(compare, initialArray) {
    this._a = (initialArray instanceof Array) ? initialArray : [];
    this._compare = compare;
};

Timeline.SortedArray.prototype.add = function(elmt) {
    var sa = this;
    var index = this.find(function(elmt2) {
        return sa._compare(elmt2, elmt);
    });
    
    if (index < this._a.length) {
        this._a.splice(index, 0, elmt);
    } else {
        this._a.push(elmt);
    }
};

Timeline.SortedArray.prototype.remove = function(elmt) {
    var sa = this;
    var index = this.find(function(elmt2) {
        return sa._compare(elmt2, elmt);
    });
    
    while (index < this._a.length && this._compare(this._a[index], elmt) == 0) {
        if (this._a[index] == elmt) {
            this._a.splice(index, 1);
            return true;
        } else {
            index++;
        }
    }
    return false;
};

Timeline.SortedArray.prototype.removeAll = function() {
    this._a = [];
};

Timeline.SortedArray.prototype.elementAt = function(index) {
    return this._a[index];
};

Timeline.SortedArray.prototype.length = function() {
    return this._a.length;
};

Timeline.SortedArray.prototype.find = function(compare) {
    var a = 0;
    var b = this._a.length;
    
    while (a < b) {
        var mid = Math.floor((a + b) / 2);
        var c = compare(this._a[mid]);
        if (mid == a) {
            return c < 0 ? a+1 : a;
        } else if (c < 0) {
            a = mid;
        } else {
            b = mid;
        }
    }
    return a;
};

Timeline.SortedArray.prototype.getFirst = function() {
    return (this._a.length > 0) ? this._a[0] : null;
};

Timeline.SortedArray.prototype.getLast = function() {
    return (this._a.length > 0) ? this._a[this._a.length - 1] : null;
};

/*==================================================
 *  Event Index
 *==================================================
 */

Timeline.EventIndex = function(unit) {
    var eventIndex = this;
    
    this._unit = (unit != null) ? unit : Timeline.NativeDateUnit;
    this._events = new Timeline.SortedArray(
        function(event1, event2) {
            return eventIndex._unit.compare(event1.getStart(), event2.getStart());
        }
    );
    this._indexed = true;
};

Timeline.EventIndex.prototype.getUnit = function() {
    return this._unit;
};

Timeline.EventIndex.prototype.add = function(evt) {
    this._events.add(evt);
    this._indexed = false;
};

Timeline.EventIndex.prototype.removeAll = function() {
    this._events.removeAll();
    this._indexed = false;
};

Timeline.EventIndex.prototype.getCount = function() {
    return this._events.length();
};

Timeline.EventIndex.prototype.getIterator = function(startDate, endDate) {
    if (!this._indexed) {
        this._index();
    }
    return new Timeline.EventIndex._Iterator(this._events, startDate, endDate, this._unit);
};

Timeline.EventIndex.prototype.getAllIterator = function() {
    return new Timeline.EventIndex._AllIterator(this._events);
};

Timeline.EventIndex.prototype.getEarliestDate = function() {
    var evt = this._events.getFirst();
    return (evt == null) ? null : evt.getStart();
};

Timeline.EventIndex.prototype.getLatestDate = function() {
    var evt = this._events.getLast();
    if (evt == null) {
        return null;
    }
    
    if (!this._indexed) {
        this._index();
    }
    
    var index = evt._earliestOverlapIndex;
    var date = this._events.elementAt(index).getEnd();
    for (var i = index + 1; i < this._events.length(); i++) {
        date = this._unit.later(date, this._events.elementAt(i).getEnd());
    }
    
    return date;
};

Timeline.EventIndex.prototype._index = function() {
    /*
     *  For each event, we want to find the earliest preceding
     *  event that overlaps with it, if any.
     */
    
    var l = this._events.length();
    for (var i = 0; i < l; i++) {
        var evt = this._events.elementAt(i);
        evt._earliestOverlapIndex = i;
    }
    
    var toIndex = 1;
    for (var i = 0; i < l; i++) {
        var evt = this._events.elementAt(i);
        var end = evt.getEnd();
        
        toIndex = Math.max(toIndex, i + 1);
        while (toIndex < l) {
            var evt2 = this._events.elementAt(toIndex);
            var start2 = evt2.getStart();
            
            if (this._unit.compare(start2, end) < 0) {
                evt2._earliestOverlapIndex = i;
                toIndex++;
            } else {
                break;
            }
        }
    }
    this._indexed = true;
};

Timeline.EventIndex._Iterator = function(events, startDate, endDate, unit) {
    this._events = events;
    this._startDate = startDate;
    this._endDate = endDate;
    this._unit = unit;
    
    this._currentIndex = events.find(function(evt) {
        return unit.compare(evt.getStart(), startDate);
    });
    if (this._currentIndex - 1 >= 0) {
        this._currentIndex = this._events.elementAt(this._currentIndex - 1)._earliestOverlapIndex;
    }
    this._currentIndex--;
    
    this._maxIndex = events.find(function(evt) {
        return unit.compare(evt.getStart(), endDate);
    });
    
    this._hasNext = false;
    this._next = null;
    this._findNext();
};

Timeline.EventIndex._Iterator.prototype = {
    hasNext: function() { return this._hasNext; },
    next: function() {
        if (this._hasNext) {
            var next = this._next;
            this._findNext();
            
            return next;
        } else {
            return null;
        }
    },
    _findNext: function() {
        var unit = this._unit;
        while ((++this._currentIndex) < this._maxIndex) {
            var evt = this._events.elementAt(this._currentIndex);
            if (unit.compare(evt.getStart(), this._endDate) < 0 &&
                unit.compare(evt.getEnd(), this._startDate) > 0) {
                
                this._next = evt;
                this._hasNext = true;
                return;
            }
        }
        this._next = null;
        this._hasNext = false;
    }
};

Timeline.EventIndex._AllIterator = function(events) {
    this._events = events;
    this._index = 0;
};

Timeline.EventIndex._AllIterator.prototype = {
    hasNext: function() {
        return this._index < this._events.length();
    },
    next: function() {
        return this._index < this._events.length() ?
            this._events.elementAt(this._index++) : null;
    }
};