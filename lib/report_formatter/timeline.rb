# Timeline formatter - creates Timeline XML stream to feed Simile Timelines
module ReportFormatter
  class ReportTimeline < Ruport::Formatter
    renders :timeline, :for => ReportRenderer

    # create the graph object and add titles, fonts, and colors
    def build_document_header
      mri = options.mri
      raise "No settings configured for Timeline" if mri.timeline.nil?
    end

    # Generates the body of the timeline
    def build_document_body
      mri = options.mri
      tz = mri.get_time_zone(Time.zone.name)
      # Calculate the earliest time of events to show
      unless mri.timeline[:last_unit].nil?
        #       START of TIMELINE TIMEZONE Code
        @start_time = format_timezone(Time.now, tz, 'raw') - mri.timeline[:last_time].to_i.send(mri.timeline[:last_unit].downcase)
        #       END of TIMELINE TIMEZONE Code
      end

      mri.extras ||= {} # Create hash to store :tl_position setting

      @events = []
      @events_data = []
      tlfield = mri.timeline[:field].split("-") # Split the table and field
      if tlfield.first.include?(".")                    # If table has a period (from a sub table)
        col = tlfield.first.split(".").last + "." + tlfield.last  # use subtable.field
      else
        col = tlfield.last                             # Not a subtable, just grab the field name
      end

      # some of the OOTB reports have db as EventStream or PolicyEvent,
      # those do not have event categories, so need to go thru else block for such reports.
      if (mri.db == "EventStream" || mri.db == "PolicyEvent") && mri.rpt_options.try(:[], :categories)
        mri.rpt_options[:categories].each do |_, options|
          @events_data = []
          all_events = mri.table.data.select { |e| options[:event_groups].include?(e.event_type) }
          all_events.each do |row|
            tl_event(row, col) # Add this row to the tl event xml
          end
          @events.push(:name => options[:display_name],
                       :data => [@events_data])
        end
      else
        mri.table.data.each_with_index do |row, _d_idx|
          tl_event(row, col)   # Add this row to the tl event xml
        end
        @events.push(:data => [@events_data])
      end
      #     START of TIMELINE TIMEZONE Code
      mri.extras[:tl_position] ||= format_timezone(Time.now, tz, 'raw') # If position not set, default to now
      #     END of TIMELINE TIMEZONE Code
      output << @events.to_json
    end

    # Methods to convert record id (id, fixnum, 12000000000056) to/from compressed id (cid, string, "12c56")
    #   for use in UI controls (i.e. tree node ids, pulldown list items, etc)
    def to_cid(id)
      ApplicationRecord.compress_id(id)
    end

    def tl_event(row, col)
      mri = options.mri
      tz = mri.get_time_zone(Time.zone.name)
      etime = row[col]
      return if etime.nil?                              # Skip nil dates - Sprint 41
      return if !@start_time.nil? && etime < @start_time # Skip if before start time limit
      #     START of TIMELINE TIMEZONE Code
      mri.extras[:tl_position] ||= format_timezone(etime.to_time, tz, 'raw')
      if mri.timeline[:position] && mri.timeline[:position] == "First"
        mri.extras[:tl_position] = format_timezone(etime.to_time, tz, 'raw') if format_timezone(etime.to_time, tz, 'raw') < format_timezone(mri.extras[:tl_position], tz, 'raw')
      elsif mri.timeline[:position] && mri.timeline[:position] == "Current"
        # if there is item with current time or greater then use that else, use right most one.
        if format_timezone(etime.to_time, tz, 'raw') >= format_timezone(Time.now, tz, 'raw') && format_timezone(etime.to_time, tz, 'raw') <= format_timezone(mri.extras[:tl_position], tz, 'raw')
          mri.extras[:tl_position] = format_timezone(etime.to_time, tz, 'raw')
        else
          mri.extras[:tl_position] = format_timezone(etime.to_time, tz, 'raw') if format_timezone(etime.to_time, tz, 'raw') > format_timezone(mri.extras[:tl_position], tz, 'raw')
        end
      else
        mri.extras[:tl_position] = format_timezone(etime.to_time, tz, 'raw') if format_timezone(etime.to_time, tz, 'raw') > format_timezone(mri.extras[:tl_position], tz, 'raw')
      end
      #     mri.extras[:tl_position] ||= etime.to_time
      #     if mri.timeline[:position] && mri.timeline[:position] == "First"
      #       mri.extras[:tl_position] = etime.to_time if etime.to_time < mri.extras[:tl_position]
      #     else
      #       mri.extras[:tl_position] = etime.to_time if etime.to_time > mri.extras[:tl_position]
      #     end
      #     END of TIMELINE TIMEZONE Code
      if row["id"]  # Make sure id column is present
        rec = mri.db.constantize.find_by_id(row['id'])
      end
      unless rec.nil?
        case mri.db
        when "BottleneckEvent"
          #         e_title = "#{ui_lookup(:model=>rec[:resource_type])}: #{rec[:resource_name]}"
          e_title = rec[:resource_name]
          e_image = ActionController::Base.helpers.image_path("100/#{bubble_icon(rec)}.png")
          e_icon = ActionController::Base.helpers.image_path("timeline/#{rec.event_type.downcase}_#{rec[:severity]}.png")
        #         e_text = e_title # Commented out since name is showing in the columns anyway
        when "Vm"
          e_title = rec[:name]
          e_icon = ActionController::Base.helpers.image_path("timeline/vendor-#{rec.vendor.downcase}.png")
          e_image = ActionController::Base.helpers.image_path("100/os-#{rec.os_image_name.downcase}.png")
        when "Host"
          e_title = rec[:name]
          e_icon = ActionController::Base.helpers.image_path("timeline/vendor-#{rec.vmm_vendor_display.downcase}.png")
          e_image = ActionController::Base.helpers.image_path("100/os-#{rec.os_image_name.downcase}.png")
        when "EventStream"
          ems_cloud = false
          if rec[:ems_id] && ExtManagementSystem.exists?(rec[:ems_id])
            ems = ExtManagementSystem.find(rec[:ems_id])
            ems_cloud =  true if ems.kind_of?(EmsCloud)
            ems_container = true if ems.kind_of?(::ManageIQ::Providers::ContainerManager)
            ems_mw = true if ems.kind_of?(::ManageIQ::Providers::MiddlewareManager)
          end
          if !(ems_cloud || ems_mw)
            e_title = if rec[:vm_name] # Create the title using VM name
                        rec[:vm_name]
                      elsif rec[:host_name] # or Host Name
                        rec[:host_name]
                      elsif rec[:ems_cluster_name] # or Cluster Name
                        rec[:ems_cluster_name]
                      elsif rec[:container_name]
                        rec[:container_name]
                      elsif rec[:container_group_name]
                        rec[:container_group_name]
                      elsif rec[:container_replicator_name]
                        rec[:container_replicator_name]
                      elsif rec[:container_node_name]
                        rec[:container_node_name]
                      end
          elsif ems_mw
            mw_name_cols = EmsEvent.column_names.select { |n| n.match('middleware_.+_name') }
            title_col = mw_name_cols.find { |c| rec[c] }
            e_title = rec[title_col] unless title_col.nil?
          end
          e_title ||= ems ? ems.name : "No VM, Host, or MS"
          e_icon = ActionController::Base.helpers.image_path("timeline/#{timeline_icon("vm_event", rec.event_type.downcase)}.png")
          # See if this is EVM's special event
          if rec.event_type == "GeneralUserEvent"
            if rec.message.include?("EVM SmartState Analysis")
              e_icon =  ActionController::Base.helpers.image_path("timeline/evm_analysis.png")
            end
          end
          if rec[:vm_or_template_id] && Vm.exists?(rec[:vm_or_template_id])
            e_image = ActionController::Base.helpers.image_path("100/os-#{Vm.find(rec[:vm_or_template_id]).os_image_name.downcase}.png")
          end
        else
          e_title = rec[:name] ? rec[:name] : row[mri.col_order.first].to_s
          e_icon = image = nil
        end
      end

      # manipulating column order to display timestamp at the end of the bubble.
      field = mri.timeline[:field].split("-")
      if ems && ems_cloud
        # Change labels to be cloud specific
        vm_name_idx = mri.col_order.index("vm_name")
        mri.headers[vm_name_idx] = "Source Instance"
        vm_location_idx = mri.col_order.index("vm_location")
        mri.headers[vm_location_idx] = "Source Instance Location"
        dest_vm_name_idx = mri.col_order.index("dest_vm_name")
        mri.headers[dest_vm_name_idx] = "Destination Instance"
        dest_vm_location_idx = mri.col_order.index("dest_vm_location")
        mri.headers[dest_vm_location_idx] = "Destination Instance Location"
      else
        mri.col_order.delete("availability_zone.name")
        mri.headers.delete("Availability Zone")
      end
      col_order = copy_array(mri.col_order)
      headers = copy_array(mri.headers)
      i = col_order.rindex(field.last)
      if i.nil?
        # Adding a check incase timeline field came in with model/table in front of them
        # i.e. PolicyEvent.miq_policy_sets-created_on
        field_with_prefix = "#{field.first.split('.').last}.#{field.last}"
        i = col_order.rindex(field_with_prefix)
        col_order.delete(field_with_prefix)
        col_order.push(field_with_prefix)
      else
        col_order.delete(field.last)
        col_order.push(field.last)
      end
      j = headers[i]
      headers.delete(j)
      headers.push(j)

      flags = {:ems_cloud     => ems_cloud,
               :ems_container => ems_container,
               :ems_mw        => ems_mw,
               :time_zone     => tz}
      tl_message = TimelineMessage.new(row, rec, flags, mri.db)
      e_text = ''
      col_order.each_with_index do |co, co_idx|
        val = tl_message.message_html(co)
        e_text += "<b>#{headers[co_idx]}:</b>&nbsp;#{val}<br/>" unless val.to_s.empty? || co == "id"
      end
      e_text = e_text.chomp('<br/>')

      # Add the event to the timeline
      @events_data.push("start"       => format_timezone(row[col], tz, 'view'),
                        "title"       => e_title.length < 20 ? e_title : e_title[0...17] + "...",
                        "icon"        => e_icon,
                        "image"       => e_image,
                        "description" => e_text)
    end

    def bubble_icon(rec)
      case rec.resource_type.downcase
      when "emscluster"
        return "cluster"
      when "miqenterprise"
        return "enterprise"
      when "extmanagementsystem"
        if rec.resource.kind_of?(ExtManagementSystem) && rec.resource.emstype == "rhevm"
          return "vendor-redhat"
        else
          return "ems"
        end
      else
        return rec.resource_type.downcase
      end
    end

    # Return the name of an icon for a specific table, event pair
    def timeline_icon(table, event_text)
      # Create the icon hash, if it doesn't exist yet
      unless @icon_hash
        icon_dir = "#{TIMELINES_FOLDER}/icons"
        begin
          data = File.read(File.join(icon_dir, "#{table}.csv")).split("\n")
        rescue
          return table    # If we can't read the file, return the table name as the icon name
        end
        @icon_hash = {}
        data.each do |rec|
          evt, txt = rec.split(",")
          @icon_hash[evt] = txt
        end
      end
      return @icon_hash[event_text] if @icon_hash[event_text]
      table
    end
  end
end
