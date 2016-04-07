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
      tz = mri.default_time_zone(Time.zone.name)
      # Calculate the earliest time of events to show
      unless mri.timeline[:last_unit].nil?
        #       START of TIMELINE TIMEZONE Code
        @start_time = format_timezone(Time.now, tz, 'raw') - mri.timeline[:last_time].to_i.send(mri.timeline[:last_unit].downcase)
        #       END of TIMELINE TIMEZONE Code
      end

      mri.extras ||= {} # Create hash to store :tl_position setting

      if mri.extras[:browser_name] == "explorer" || mri.extras[:tl_preview]
        tl_xml = MiqXml.load("<data/>")
      else
        @events = []
      end
      tlfield = mri.timeline[:field].split("-") # Split the table and field
      if tlfield.first.include?(".")                    # If table has a period (from a sub table)
        col = tlfield.first.split(".").last + "." + tlfield.last  # use subtable.field
      else
        col = tlfield.last                             # Not a subtable, just grab the field name
      end
      mri.table.data.each_with_index do |row, _d_idx|
        tl_event(tl_xml ? tl_xml : nil, row, col)   # Add this row to the tl event xml
      end
      #     START of TIMELINE TIMEZONE Code
      mri.extras[:tl_position] ||= format_timezone(Time.now, tz, 'raw') # If position not set, default to now
      #     END of TIMELINE TIMEZONE Code
      if mri.extras[:browser_name] == "explorer" || mri.extras[:tl_preview]
        output << tl_xml.to_s
      else
        output << {:events => @events}.to_json
      end
    end

    # Methods to convert record id (id, fixnum, 12000000000056) to/from compressed id (cid, string, "12c56")
    #   for use in UI controls (i.e. tree node ids, pulldown list items, etc)
    def to_cid(id)
      ApplicationRecord.compress_id(id)
    end

    def tl_event(tl_xml, row, col)
      mri = options.mri
      tz = mri.default_time_zone(Time.zone.name)
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
          e_text = "&lt;a href='/vm/show/#{rec.id}'&gt;#{e_title}&lt;/a&gt;"
        when "Host"
          e_title = rec[:name]
          e_icon = ActionController::Base.helpers.image_path("timeline/vendor-#{rec.vmm_vendor_display.downcase}.png")
          e_image = ActionController::Base.helpers.image_path("100/os-#{rec.os_image_name.downcase}.png")
          e_text = "&lt;a href='/host/show/#{rec.id}'&gt;#{e_title}&lt;/a&gt;"
        when "EventStream"
          ems_cloud = false
          if rec[:ems_id] && ExtManagementSystem.exists?(rec[:ems_id])
            ems = ExtManagementSystem.find(rec[:ems_id])
            ems_cloud =  true if ems.kind_of?(EmsCloud)
            ems_container = true if ems.kind_of?(::ManageIQ::Providers::ContainerManager)
          end
          if !ems_cloud
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
          elsif ems                             #   or EMS name
            e_title = ems.name
          else
            e_title = "MS no longer exists"
          end
          e_title ||= "No VM, Host, or MS"
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
          e_text = e_title
        when "PolicyEvent"
          if rec[:target_name]              # Create the title using Policy description
            e_title = rec[:target_name]
          elsif rec[:miq_policy_id] && MiqPolicy.exists?(rec[:miq_policy_id])   #   or Policy name
            e_title = MiqPolicy.find(rec[:miq_policy_id]).name
          else
            e_title = "Policy no longer exists"
          end
          e_title ||= "No Policy"
          e_icon = ActionController::Base.helpers.image_path("100/event-#{rec.event_type.downcase}.png")
          # e_icon = "/images/100/vendor-ec2.png"
          e_text = e_title
          unless rec.target_id.nil?
            e_text += "<br/>&lt;a href='/#{Dictionary.gettext(rec.target_class, :type => :model, :notfound => :titleize).downcase}/show/#{to_cid(rec.target_id)}'&gt;<b> #{Dictionary.gettext(rec.target_class, :type => :model, :notfound => :titleize)}:</b> #{rec.target_name}&lt;/a&gt;"
          end

          assigned_profiles = {}
          profile_sets = rec.miq_policy_sets

          profile_sets.each do |profile|
            assigned_profiles[profile.id] = profile.description unless profile.description.nil?
          end

          unless rec.event_type.nil?
            e_text += "<br/><b>Assigned Profiles:</b> "
            assigned_profiles.each_with_index do |p, i|
              e_text += "&lt;a href='/miq_policy/explorer?profile=#{p[0]}'&gt;<b> #{p[1]}&lt;/a&gt;"
              if assigned_profiles.length > 1 && i < assigned_profiles.length
                e_text += ", "
              end
            end
          end
        else
          e_title = rec[:name] ? rec[:name] : row[mri.col_order.first].to_s
          e_icon = image = nil
          e_text = e_title
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
        # Adding a check incase timeline field came in with model/table in front of them i.e. PolicyEvent.miq_policy_sets-created_on
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

      e_text = ''
      col_order.each_with_index do |co, co_idx|
        val = ''
        # Look for fields that have matching link fields and put in the link
        if co == "vm_name" && !rec.vm_or_template_id.nil?
          val = "&lt;a href='/vm/show/#{to_cid(rec.vm_or_template_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "src_vm_name" && !rec.src_vm_id.nil?
          val = "&lt;a href='/vm/show/#{to_cid(rec.src_vm__id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "dest_vm_name" && !rec.dest_vm_or_template_id.nil?
          val = "&lt;a href='/vm/show/#{to_cid(rec.dest_vm_or_template_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "host_name" && !rec.host_id.nil?
          val = "&lt;a href='/host/show/#{to_cid(rec.host_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "dest_host_name" && !rec.dest_host_id.nil?
          val = "&lt;a href='/host/show/#{to_cid(rec.dest_host_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "ems_cluster_name" && !rec.ems_cluster_id.nil?
          val = "&lt;a href='/ems_cluster/show/#{to_cid(rec.ems_cluster_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "ext_management_system.name" && rec.ext_management_system && !rec.ext_management_system.id.nil?
          provider_id = rec.ext_management_system.id
          if ems_cloud
            # restful route is used for cloud provider unlike infrastructure provider
            val = "&lt;a href='/ems_cloud/#{provider_id}'&gt;#{row[co]}&lt;/a&gt;"
          elsif ems_container
            val = "&lt;a href='/ems_container/show/#{to_cid(provider_id)}'&gt;#{row[co]}&lt;/a&gt;"
          else
            val = "&lt;a href='/ems_infra/show/#{to_cid(provider_id)}'&gt;#{row[co]}&lt;/a&gt;"
          end
        elsif co == "availability_zone.name" && !rec.availability_zone_id.nil?
          val = "&lt;a href='/availability_zone/show/#{to_cid(rec.availability_zone_id)}'&gt;#{row[co]}&lt;/a&gt;"
        elsif co == "container_node_name"
          if rec.container_node_id
            val = "<a href='/container_node/show/#{to_cid(rec.container_node_id.id)}'>#{row[co]}</a>"
          end
        elsif co == "container_group_name"
          if rec.container_group_id
            val = "<a href='/container_group/show/#{to_cid(rec.container_group.id)}'>#{row[co]}</a>"
          end
        elsif co == "container_name"
          if rec.container_id
            val = "<a href='/container/tree_select/?id=cnt-#{to_cid(rec.container_id)}'>#{row[co]}</a>;"
          end
        elsif co == "container_replicator_name" && rec.container_replicator_id
          if rec.container_replicator_id
            val = "<a href='/container_replicator/show/#{to_cid(rec.container_replicator_id)}'>#{row[co]}</a>"
          end
        elsif mri.db == "BottleneckEvent" && co == "resource_name"
          case rec.resource_type
          when "ExtManagementSystem"
            db = ems_cloud ? "ems_cloud" : "ems_infra"
          else
            db = rec.resource_type.underscore
          end
          val = "&lt;a href='/#{db}/show/#{to_cid(rec.resource_id)}'&gt;#{rec.resource_name}&lt;/a&gt;"
        else  # Not a link field, just put in the text
          # START of TIMELINE TIMEZONE Code
          if row[co].kind_of?(Time)
            val = format_timezone(row[co], tz, "gtl")
          elsif TIMELINE_TIME_COLUMNS.include?(co)
            val = format_timezone(Time.parse(row[co].to_s), tz, "gtl")
          else
            val = row[co].to_s
          end
          # END of TIMELINE TIMEZONE Code
          #           e_text += row[co].to_s
        end
        e_text += "<b>#{headers[co_idx]}:</b> #{val}<br/>" unless val.to_s.empty? || co == "id"
      end
      e_text = e_text.chomp('<br/>')

      # Add the event to the timeline
      if mri.extras[:browser_name] == "explorer" || mri.extras[:tl_preview]
        event = tl_xml.root.add_element("event",           "start" => format_timezone(row[col], "UTC", nil),
                                                           #         "end" => Time.now,
                                                           #         "isDuration" => "true",
                                                           "title" => CGI.escapeHTML(e_title.length < 20 ? e_title : e_title[0...17] + "..."),
                                                           "icon"  => e_icon,
                                                           #         "color"=>tl_color
                                                           "image" => e_image)
        event.text = e_text
      else
        @events.push("start"       => format_timezone(row[col], tz, 'view').to_time,
                     "title"       => CGI.escapeHTML(e_title.length < 20 ? e_title : e_title[0...17] + "..."),
                     "icon"        => e_icon,
                     "image"       => e_image,
                     "description" => e_text)
      end
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
