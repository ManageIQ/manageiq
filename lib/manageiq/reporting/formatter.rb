include ActionView::Helpers::NumberHelper

require 'report_formatter/report_renderer'
require 'report_formatter/c3'
require 'report_formatter/converter'
require 'report_formatter/html'
require 'report_formatter/text'
require 'report_formatter/timeline'

module ReportFormatter
  BLANK_VALUE = "Unknown"         # Chart constant for nil or blank key values
  CRLF = "\r\n"
  LEGEND_LENGTH = 11              # Top legend text limit
  LABEL_LENGTH = 21               # Chart label text limit
end
