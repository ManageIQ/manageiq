module ManageIQ
  module Reporting
    module Formatter
      class HTML < Ruport::Formatter
        renders :html, :for => ManageIQ::Reporting::Formatter::ReportRenderer

        def build_html_title
          mri = options.mri
          mri.html_title = ''
          mri.html_title << " <div style='height: 10px;'></div>"
          mri.html_title << "<ul id='tab'>"
          mri.html_title << "<li class='active'><a class='active'>"
          mri.html_title << " #{mri.title}" unless mri.title.nil?
          mri.html_title << "</a></li></ul>"
          mri.html_title << '<div class="clr"></div><div class="clr"></div><div class="b"><div class="b"><div class="b"></div></div></div>'
          mri.html_title << '<div id="element-box"><div class="t"><div class="t"><div class="t"></div></div></div><div class="m">'
        end

        def pad(str, len)
          return "".ljust(len) if str.nil?
          str = str.slice(0, len) # truncate long strings
          str.ljust(len) # pad with whitespace
        end

        def build_document_header
          build_html_title
        end

        def build_document_body
          mri = options.mri
          output << "<table class='table table-striped table-bordered'>"
          output << "<thead>"
          output << "<tr>"

          # table heading
          unless mri.headers.nil?
            mri.headers.each do |h|
              output << "<th>" << CGI.escapeHTML(h.to_s) << "</th>"
            end
            output << "</tr>"
            output << "</thead>"
          end
          output << '<tbody>'
          output << mri.build_html_rows.join
          output << '</tbody>'
        end

        def build_document_footer
          mri = options.mri
          output << "<tfoot>"
          output << "<td colspan='15'>"
          output << "<del class='container'>"
          output << "</del>"
          output << "</td>"
          output << "</tfoot>"
          output << "</table>"

          if mri.filter_summary
            output << mri.filter_summary.to_s
          end
        end

        def finalize_document
          output
        end
      end
    end
  end
end
