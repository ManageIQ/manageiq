function centerTimeline(date) {
    tl.getBand(0).setCenterVisibleDate(Timeline.DateTime.parseGregorianDateTime(date));
}
var timerID = null;

function cleanString(s) {
    return s.replace(/^\s+/, '').replace(/\s+$/, '');
}
function performFiltering(timeline, bandIndices) {
    timerID = null;
    var filterMatcher = null;    
    
    var regexes = [];
    var hasHighlights = false;
    for (var x = 0; x < document.forms["hiddenForm"].length; x++) {
        var input = document.forms["hiddenForm"][x];
        var text2 = cleanString(input.value);
        if (text2.length > 0) {
            hasHighlights = true;
            regexes.push(new RegExp(text2, "i"));
        } else {
            regexes.push(null);
        }
    }
    var highlightMatcher = hasHighlights ? function(evt) {
        var text = evt.getText();
        var description = evt.getDescription();
        for (var x = 0; x < regexes.length; x++) {
            var regex = regexes[x];
            if (regex != null && (regex.test(text) || regex.test(description))) {
                return x;
            }
        }
        return -1;
    } : null;
    
    for (var i = 0; i < bandIndices.length; i++) {
        var bandIndex = bandIndices[i];
        timeline.getBand(bandIndex).getEventPainter().setFilterMatcher(filterMatcher);
        timeline.getBand(bandIndex).getEventPainter().setHighlightMatcher(highlightMatcher);
    }
    timeline.paint();
}
