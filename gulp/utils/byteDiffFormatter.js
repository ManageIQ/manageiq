'use strict';

/**
 * Format a number as a percentage
 * @param {Number} num Number to format as a percent
 * @param {Number} precision Precision of the decimal
 * @return {String} Formatted percentage
 */
function formatPercent(num, precision) {
  return (num * 100).toFixed(precision);
}

/**
 * Formatter for bytediff to display the size changes after processing
 * @param {Object} data - byte data
 * @return {String} Difference in bytes, formatted
 */
module.exports = function bytediffFormatter(data) {
  var difference = (data.savings > 0) ? ' smaller.' : ' larger.';
  return data.fileName + ' went from ' +
    (data.startSize / 1000).toFixed(2) + ' kB to ' + (data.endSize / 1000).toFixed(2) + ' kB' +
    ' and is ' + formatPercent(1 - data.percent, 2) + '%' + difference;
}
