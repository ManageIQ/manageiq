module ManageIQ
  module Reporting
    module Formatter
      class TimelineMessage
        TIMELINE_TIME_COLUMNS = %w(created_on timestamp).freeze

        def initialize(row, event, flags, db)
          @row, @event, @flags, @db = row, event, flags, db
        end

        def message_html(column)
          @column = column
          field = column.tr('.', '_').to_sym
          respond_to?(field, true) ? send(field).to_s : text
        end

        private

        def vm_name
          "<a href=/vm/show/#{@event.vm_or_template_id}>#{text}</a>" if @event.vm_or_template_id
        end

        def src_vm_name
          "<a href=/vm/show/#{@event.src_vm_or_template.id}>#{text}</a>" if @event.src_vm_or_template
        end

        def dest_vm_name
          "<a href=/vm/show/#{@event.dest_vm_or_template_id}>#{text}</a>" if @event.dest_vm_or_template_id
        end

        def host_name
          "<a href=/host/show/#{@event.host_id}>#{text}</a>" if @event.host_id
        end

        def dest_host_name
          "<a href=/host/show/#{@event.dest_host_id}>#{text}</a>" if @event.dest_host_id
        end

        def target_name
          e_text = if @event.target_name # Create the title using Policy description
                     @event.target_name
                   elsif @event.miq_policy_id && MiqPolicy.exists?(@event.miq_policy_id) # or Policy name
                     MiqPolicy.find(@event.miq_policy_id).name
                   else
                     _("Policy no longer exists")
                   end
          unless @event.target_id.nil?
            e_text += "<br><b>#{Dictionary.gettext(@event.target_class, :type => :model, :notfound => :titleize)}:</b>&nbsp;"
            e_text += "<a href=/#{@event.target_class.underscore}/show/#{@event.target_id}>#{@event.target_name}</a>"
          end
          assigned_profiles = @event.miq_policy_sets.each_with_object({}) do |profile, hsh|
            hsh[profile.id] = profile.description unless profile.description.nil?
          end

          unless @event.event_type.nil?
            e_text += "<br/><b>#{_("Assigned Profiles")}:</b>&nbsp;"
            assigned_profiles.each_with_index do |p, i|
              e_text += "<a href=/miq_policy/explorer/?profile=#{p[0]}>#{p[1]}</a>"
              e_text += ", " if assigned_profiles.length > 1 && i < assigned_profiles.length
            end
          end
          e_text
        end

        def ems_cluster_name
          "<a href=/ems_cluster/show/#{@event.ems_cluster_id}>#{text}</a>" if @event.ems_cluster_id
        end

        def availability_zone_name
          if @event.availability_zone_id
            "<a href=/availability_zone/show/#{@event.availability_zone_id}>#{text}</a>"
          end
        end

        def container_node_name
          "<a href=/container_node/show/#{@event.container_node_id}>#{text}</a>" if @event.container_node_id
        end

        def container_group_name
          "<a href=/container_group/show/#{@event.container_group_id}>#{text}</a>" if @event.container_group_id
        end

        def container_name
          "<a href=/container/tree_select/?id=cnt-#{@event.container_id}>#{text}</a>" if @event.container_id
        end

        def container_replicator_name
          if @event.container_replicator_id
            "<a href=/container_replicator/show/#{@event.container_replicator_id}>#{text}</a>"
          end
        end

        def middleware_name
          mw_id_cols = EmsEvent.column_names.select { |n| n.match('middleware_.+_id') }
          mw_id_col  = mw_id_cols.find { |c| @event[c] }
          unless mw_id_col.nil?
            mw_type     = mw_id_col.slice(0, mw_id_col.rindex('_id'))
            mw_name_col = mw_type + '_name'
            "<a href=/#{mw_type}/show/#{@event[mw_id_col]}>#{@event[mw_name_col]}</a>"
          end
        end

        def ext_management_system_name
          if @event.ext_management_system && @event.ext_management_system.id
            provider_id = @event.ext_management_system.id
            if ems_cloud
              # restful route is used for cloud provider unlike infrastructure provider
              "<a href=/ems_cloud/#{provider_id}>#{text}</a>"
            elsif ems_container
              "<a href=/ems_container/#{provider_id}>#{text}</a>"
            elsif ems_mw
              "<a href=/ems_middleware/#{provider_id}>#{text}</a>"
            else
              "<a href=/ems_infra/#{provider_id}>#{text}</a>"
            end
          end
        end

        def resource_name
          if @db == 'BottleneckEvent'
            db = if ems_cloud && @event.resource_type == 'ExtManagementSystem'
                   'ems_cloud'
                 elsif @event.resource_type == 'ExtManagementSystem'
                   'ems_infra'
                 else
                   "#{@event.resource_type.underscore}/show"
                 end
            "<a href=/#{db}/#{@event.resource_id}>#{@event.resource_name}</a>"
          end
        end

        def text
          if @row[@column].kind_of?(Time) || TIMELINE_TIME_COLUMNS.include?(@column)
            format_timezone(Time.parse(@row[@column].to_s).utc, @flags[:time_zone], "gtl")
          else
            @row[@column].to_s
          end
        end

        def ems_cloud
          @flags[:ems_cloud]
        end

        def ems_container
          @flags[:ems_container]
        end

        def ems_mw
          @flags[:ems_mw]
        end
      end
    end
  end
end
