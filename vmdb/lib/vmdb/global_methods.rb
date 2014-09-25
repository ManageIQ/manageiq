module Vmdb
  module GlobalMethods
    def is_numeric?(n)
      begin
        Float n
      rescue
        false
      else
        true
      end
    end

    # Check to see if a field contains a valid integer
    def is_integer?(n)
      begin
        Integer n
      rescue
        false
      else
        true
      end
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
      MiqExpression.col_type(model, column)
    end

    # Had to add timezone methods here, they are being called from models
    def get_timezone_abbr(typ="server")
      # return timezone abbreviation
      if typ == "server"
        tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone)
        tz = ActiveSupport::TimeZone::MAPPING[tz.blank? ? "UTC" : tz]
        time = Time.now
      else
        tz = Time.zone
        time = Time.zone.now
      end
      new_time = time.in_time_zone(tz)
      abbr = new_time.strftime("%Z")
      return abbr
    end

    def get_timezone_offset(typ="server",formatted=false)
      # returns utc_offset of timezone
      if typ == "server"
        tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone)
        tz = ActiveSupport::TimeZone::MAPPING[tz.blank? ? "UTC" : tz]
      else
        tz = get_timezone_for_userid(session[:userid])
        @tz = tz unless tz.blank?
        tz = ActiveSupport::TimeZone::MAPPING[@tz]
      end
      ActiveSupport::TimeZone.all.each do  |a|
        if ActiveSupport::TimeZone::MAPPING[a.name] == tz
          if formatted
            return a.formatted_offset
          else
            return a.utc_offset
          end
        end
      end
    end

    def get_timezone_for_userid(userid)
      db_user = User.find_by_userid(userid)
      if !db_user.blank?
        if db_user.settings && db_user.settings[:display] && !db_user.settings[:display][:timezone].blank?
          tz = db_user.settings[:display][:timezone]
        else
          tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone)
        end
      else    # if userid is not valid
        tz = "UTC"
      end

      tz
    end

    #returns formatted time in specified timezone and format
    def format_timezone(time,timezone=Time.zone.name,ftype="view")
      timezone = timezone.name if timezone.is_a?(ActiveSupport::TimeZone)   # If a Timezone object comes in, just get the name
      if !time.blank?
        new_time = time.in_time_zone(timezone)
        case ftype
        when "gtl"                                  # for gtl views
          new_time = new_time.strftime("%m/%d/%y %H:%M:%S %Z")
        when "on_at"                                  # for gtl views
          new_time = new_time.strftime("on %m/%d/%y at %H:%M:%S %Z")
        when "fname"                                # for download filename
          new_time = new_time.strftime("%Y_%m_%d")
        when "date"                                 # for just mm/dd/yy
          new_time = new_time.strftime("%m/%d/%y")
        when "datetime"                             # mm/dd/yy hh:mm:ss
          new_time = new_time.strftime("%m/%d/%y %H:%M:%S")
        when "export_filename","support_log_fname"    # for export/log filename
          new_time = new_time.strftime("%Y%m%d_%H%M%S")
        when "tl"
          new_time = new_time.strftime("%a %b %d %Y %H:%M:%S") + " " + Time.zone.to_s
          new_time = new_time.gsub(/\) [a-zA-Z0-9\s\S]*/,")")
        when "raw"                                  # return without formatting
        when "compare_hdr"                          # for drift/compare headers
          new_time = new_time.strftime("%m/%d/%y %H:%M %Z")
        when "widget_footer"                        # for widget footers
          new_time = new_time.strftime("%m/%d/%y %H:%M")
        else                                        # for summary screens
          new_time = new_time.strftime("%a %b %d %H:%M:%S %Z %Y")
        end
      else    #if time is nil
        new_time = ""
      end
      return new_time
    end

    # Get dictionary name with default settings
    def ui_lookup(options = {})
      # Pass in singular or plural key to determine format of returned string
      if options[:table]
        Dictionary::gettext(options[:table], :type=>:table, :notfound=>:titleize).singularize
      elsif options[:tables]
        Dictionary::gettext(options[:tables], :type=>:table, :notfound=>:titleize).pluralize
      elsif options[:model]
        Dictionary::gettext(options[:model], :type=>:model, :notfound=>:titleize).singularize
      elsif options[:models]
        Dictionary::gettext(options[:models], :type=>:model, :notfound=>:titleize).pluralize
      else
        ''
      end
    end

    # Wrap a report html table body with html table tags and headers for the columns
    def report_build_html_table(report, table_body)
      html = String.new
      html << "<table class='style3'>"
      html << "<thead>"
      html << "<tr>"

      # table headings
      unless report.headers.nil?
        report.headers.each do |h|
          html << "<th class='title'>" << CGI.escapeHTML(h.to_s) << "</th>"
        end
        html << "</tr>"
        html << "</thead>"
      end
      html << '<tbody>'
      return html << table_body << '</tbody></table>'
    end
  end
end
