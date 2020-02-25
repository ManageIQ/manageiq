module ManageIQ
  module Reporting
    module Formatter
      class ReportRenderer < Ruport::Controller
        stage :document_header, :document_body, :document_footer
        finalize :document
        options { |o| o.mri = o.show_title = o.theme = o.table_width = o.alignment = o.graph_options = nil }
      end
    end
  end
end
