# Timeline formatter - creates Timeline XML stream to feed Simile Timelines
require_dependency 'manageiq/reporting/formatter/timeline_message'

module ManageIQ
  module Reporting
    module Formatter
      class Timeline < Ruport::Formatter
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
            event_map = mri.table.data.each_with_object({}) do |event, buckets|
              bucket_name = mri.rpt_options[:categories].detect do |_, options|
                options[:include_set].include?(event.event_type)
              end&.last.try(:[], :display_name)

              bucket_name ||= mri.rpt_options[:categories].detect do |_, options|
                options[:regexes].any? { |regex| regex.match(event.event_type) }
              end.last[:display_name]

              buckets[bucket_name] ||= []
              buckets[bucket_name] << event
            end

            event_map.each do |name, events|
              @events_data = []
              events.each { |row| tl_event(row, col) }
              @events.push(:name => name, :data => [@events_data])
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
          #     END of TIMELINE TIMEZONE Code
          if row["id"]  # Make sure id column is present
            rec = mri.db.constantize.find_by_id(row['id'])
          end
          unless rec.nil?
            case mri.db
            when "Vm"
              e_title = rec[:name]
            when "Host"
              e_title = rec[:name]
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
              end
            else
              e_title = rec[:name] ? rec[:name] : row[mri.col_order.first].to_s
            end
          end
          e_title ||= ems ? ems.name : "No VM, Host, or MS"

          # manipulating column order to display timestamp at the end of the bubble.
          field = mri.timeline[:field].split("-")
          if ems && ems_cloud
            # Change labels to be cloud specific
            vm_name_idx = mri.col_order.index("vm_name")
            mri.headers[vm_name_idx] = "Source Instance" if vm_name_idx
            vm_location_idx = mri.col_order.index("vm_location")
            mri.headers[vm_location_idx] = "Source Instance Location" if vm_location_idx
            dest_vm_name_idx = mri.col_order.index("dest_vm_name")
            mri.headers[dest_vm_name_idx] = "Destination Instance" if dest_vm_name_idx
            dest_vm_location_idx = mri.col_order.index("dest_vm_location")
            mri.headers[dest_vm_location_idx] = "Destination Instance Location" if dest_vm_location_idx
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
                   :time_zone     => tz}
          tl_message = TimelineMessage.new(row, rec, flags, mri.db)
          event_data = {}
          col_order.each_with_index do |co, co_idx|
            value = tl_message.message_html(co)
            next if value.to_s.empty? || co == "id"
            event_data[co] = {
              :value => value,
              :text  => headers[co_idx]
            }
          end

          # Add the event to the timeline
          @events_data.push("start" => format_timezone(row[col], tz, 'view'),
                            "title" => e_title.length < 20 ? e_title : e_title[0...17] + "...",
                            "event" => event_data)
        end
      end
    end
  end
end
