module Vmdb
  module GlobalMethods
    def is_numeric?(n)
      Float(n)
    rescue
      false
    else
      true
    end

    # Check to see if a field contains a valid integer
    def is_integer?(n)
      Integer(n)
    rescue
      false
    else
      true
    end

    # Copy a hash, duplicating any embedded hashes/arrays contained within
    def copy_hash(hashin)
      hashin.deep_clone
    end

    # Copy an array, duplicating any embedded hashes/arrays contained within
    def copy_array(arrayin)
      arrayin.deep_clone
    end

    def column_type(model, column)
      MiqExpression.create_field(model, [], column).column_type
    end

    # Had to add timezone methods here, they are being called from models
    # returns formatted time in specified timezone and format
    def format_timezone(time, timezone = Time.zone.name, ftype = "view")
      timezone = timezone.name if timezone.kind_of?(ActiveSupport::TimeZone)   # If a Timezone object comes in, just get the name
      if !time.blank?
        new_time = time.in_time_zone(timezone)
        case ftype
        when "gtl"                                  # for gtl views
          new_time = I18n.l(new_time.to_date) + new_time.strftime(" %H:%M:%S %Z")
        when "fname"                                # for download filename
          new_time = new_time.strftime("%Y_%m_%d")
        when "date"                                 # for just mm/dd/yy
          new_time = I18n.l(new_time.to_date)
        when "export_filename"                      # for export/log filename
          new_time = new_time.strftime("%Y%m%d_%H%M%S")
        when "tl"
          new_time = I18n.l(new_time)
        when "raw"                                  # return without formatting
        when "compare_hdr"                          # for drift/compare headers
          new_time = I18n.l(new_time, :format => :long) + new_time.strftime(" %Z")
        when "widget_footer"                        # for widget footers
          new_time = I18n.l(new_time, :format => :long)
        else                                        # for summary screens
          new_time = I18n.l(new_time)
        end
      else    # if time is nil
        new_time = ""
      end
      new_time
    end

    # Get dictionary name with default settings
    def ui_lookup(options = {})
      if options[:table]
        Dictionary.gettext(options[:table], :type => :table, :notfound => :titleize, :plural => false)
      elsif options[:tables]
        Dictionary.gettext(options[:tables], :type => :table, :notfound => :titleize, :plural => true)
      elsif options[:model]
        Dictionary.gettext(options[:model], :type => :model, :notfound => :titleize, :plural => false)
      elsif options[:models]
        Dictionary.gettext(options[:models], :type => :model, :notfound => :titleize, :plural => true)
      elsif options[:ui_title]
        Dictionary.gettext(options[:ui_title], :type => :ui_title)
      else
        ''
      end
    end

    # Wrap a report html table body with html table tags and headers for the columns
    def report_build_html_table(report, table_body, breakable = true)
      html = ''
      html << "<table class=\"table table-striped table-bordered #{breakable ? '' : 'non-breakable'}\">"
      html << "<thead>"
      html << "<tr>"

      # table headings
      unless report.headers.nil?
        report.headers.each_with_index do |h, i|
          col = report.col_order[i]
          next if report.column_is_hidden?(col)

          html << "<th>" << CGI.escapeHTML(_(h.to_s)) << "</th>"
        end
        html << "</tr>"
        html << "</thead>"
      end
      html << '<tbody>'
      html << table_body << '</tbody></table>'
    end
  end
end
