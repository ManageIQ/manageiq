# Make these constants globally available
# TODO: Stop including constants in Object via UiConstants module since these
# singleton constants don't play nice with Rails class reloading in dev mode.
# Either access the constants through the UiConstants namespace or get it to
# work with including it in all the views/controllers via application_helper.
include ActionView::Helpers::NumberHelper

require 'report_formatter/report_renderer'
require 'report_formatter/jqplot'
require 'report_formatter/c3'
require 'report_formatter/html'
require 'report_formatter/text'
require 'report_formatter/timeline'

module ReportFormatter
  BLANK_VALUE = "Unknown"         # Chart constant for nil or blank key values
  CRLF = "\r\n"
  LEGEND_LENGTH = 11              # Top legend text limit
  LABEL_LENGTH = 21               # Chart label text limit
end
