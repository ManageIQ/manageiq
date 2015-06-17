/** miq-calendar directive
 * should be on input[type=text]
 * original value (if any) will be parsed as an ISO date
 * output value will be in ISO format as well
 * optionally accepts date-from=(iso), date-to=(iso)
 * + date-format in $filter('date') format (MM/dd/yyyy is the default)
 */
miqAngularApplication.directive('miqCalendar', ['$timeout', '$parse', '$filter', function($timeout, $parse, $filter) {
  return {
    require: 'ngModel',
    link: function(scope, elem, attr, ctrl) {
      var elem_id = elem.attr('id');

      // prevents clash with old calendar code
      if (elem_id && elem_id.match(/^miq_date/)) {
        console.error("Can't use miqCalendar together with miqBuildCalendar magic, sorry", elem);
        return;
      }

      // temporary - dhtmlx needs id
      if (! elem_id) {
        // needs jQuery UI
        elem.uniqueId()
        elem_id = elem.attr('id');
      }

      var cal = new dhtmlxCalendarObject(elem_id);
      cal.setDateFormat("%Y-%m-%d");
      cal.setSkin("dhx_skyblue");
      cal.hideTime();
      cal.setPosition('right');
      // start week from sunday, default is (1) monday
      cal.setWeekStartDay(7);

      // replaces miq_cal_dateFrom & miq_cal_dateTo
      if (attr.dateFrom && attr.dateTo) {
        cal.setSensitiveRange(new Date(attr.dateFrom), new Date(attr.dateTo));
      } else if (attr.dateFrom && ! attr.dateTo) {
        cal.setSensitiveRange(new Date(attr.dateFrom));
      }

      var modelSetter = $parse(attr.ngModel).assign;

      var refreshModel = function() {
        // trigger a digest cycle - not $apply because that one triggers an error when called when already in a digest cycle
        $timeout(function() {
          var val = elem.val();
          modelSetter(scope, val);
        });
      };

      var refreshCal = function(val) {
        // dhtmlxCalendar handles both the set input format (m/d/Y), the default one, or a Date object
        cal.setDate(val);
        if (ctrl.$setDirty) // angular 1.2 compatibility
          ctrl.$setDirty();
      }

      ctrl.$formatters.unshift(function(val) {
        if (!val)
          return "";

        return $filter('date')(new Date(val), attr.dateFormat || 'MM/dd/yyyy');
      });

      elem.on('change', refreshModel);
      cal.attachEvent('onClick', refreshModel);
      scope.$watch(attr.ngModel, refreshCal);
    },
  };
}]);
