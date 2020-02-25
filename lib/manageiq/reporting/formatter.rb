include ActionView::Helpers::NumberHelper

require_dependency 'manageiq/reporting/formatter/report_renderer'
require_dependency 'manageiq/reporting/formatter/c3'
require_dependency 'manageiq/reporting/formatter/converter'
require_dependency 'manageiq/reporting/formatter/html'
require_dependency 'manageiq/reporting/formatter/text'
require_dependency 'manageiq/reporting/formatter/timeline'

module ManageIQ
  module Reporting
    module Formatter
      BLANK_VALUE = "Unknown"         # Chart constant for nil or blank key values
      CRLF = "\r\n"
      LEGEND_LENGTH = 11              # Top legend text limit
      LABEL_LENGTH = 21               # Chart label text limit
    end
  end
end

# Deprecate the constants within ReportFormatter with a helpful replacement.
module ReportFormatter
  include ActiveSupport::Deprecation::DeprecatedConstantAccessor
  deprecate_constant 'BLANK_VALUE',       'ManageIQ::Reporting::Formatter::BLANK_VALUE'
  deprecate_constant 'CRLF',              'ManageIQ::Reporting::Formatter::CRLF'
  deprecate_constant 'LABEL_LENGTH',      'ManageIQ::Reporting::Formatter::LABEL_LENGTH'
  deprecate_constant 'LEGEND_LENGTH',     'ManageIQ::Reporting::Formatter::LEGEND_LENGTH'

  deprecate_constant 'C3Formatter',       'ManageIQ::Reporting::Formatter::C3'
  deprecate_constant 'C3Series',          'ManageIQ::Reporting::Formatter::C3Series'
  deprecate_constant 'C3Charting',        'ManageIQ::Reporting::Formatter::C3Charting'
  deprecate_constant 'ChartCommon',       'ManageIQ::Reporting::Formatter::ChartCommon'
  deprecate_constant 'Converter',         'ManageIQ::Reporting::Formatter::Converter'
  deprecate_constant 'ReportHTML',        'ManageIQ::Reporting::Formatter::HTML'
  deprecate_constant 'ReportRenderer',    'ManageIQ::Reporting::Formatter::ReportRenderer'
  deprecate_constant 'ReportText',        'ManageIQ::Reporting::Formatter::Text'
  deprecate_constant 'ReportTimeline',    'ManageIQ::Reporting::Formatter::Timeline'
  deprecate_constant 'TimelineMessage',   'ManageIQ::Reporting::Formatter::TimelineMessage'
end
