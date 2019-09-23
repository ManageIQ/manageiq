module MiqSchedule::ImportExport
  extend ActiveSupport::Concern

  SKIPPED_ATTRIBUTES = %w[id created_on updated_at last_run_on zone_id].freeze

  def handle_attributes_for_miq_report(export_attributes)
    export_attributes['sched_action'][:options][:miq_group_description] = MiqGroup.find_by(:id => export_attributes['sched_action'][:options][:miq_group_id])&.description
    export_attributes
  end

  def handle_attributes(export_attributes)
    if export_attributes['resource_type'] == 'MiqReport' || export_attributes['resource_type'] == 'MiqWidget'
      filter_record_id = export_attributes['filter'].exp["="]["value"]
      resource = export_attributes["resource_type"].safe_constantize.find_by(:id => filter_record_id)
      export_attributes["filter_resource_name"] = export_attributes["resource_type"] == "MiqReport" ? resource.name : resource.description if resource
    elsif export_attributes["filter"]&.kind_of?(MiqExpression)
      export_attributes['filter'] = MiqExpression.new(export_attributes['filter'].exp)
    end

    export_attributes['MiqSearchContent'] = MiqSearch.find_by(:id => export_attributes['miq_search_id']).export_to_array if export_attributes['miq_search_id']

    export_attributes['FileDepotContent'] = FileDepot.find_by(:id => export_attributes['file_depot_id']).export_to_array if export_attributes['file_depot_id']

    if export_attributes['resource_id']
      schedule_resource = export_attributes["resource_type"].safe_constantize.find_by(:id => export_attributes['resource_id'])
      export_attributes['resource_name'] = schedule_resource&.name
    end

    export_attributes
  end

  def export_to_array
    export_attributes = attributes.except(*SKIPPED_ATTRIBUTES)
    export_attributes['filter'] = MiqExpression.new(export_attributes["filter"].exp) if export_attributes["filter"]&.kind_of?(MiqExpression)
    export_attributes =
      case export_attributes['resource_type']
      when "MiqReport"
        handle_attributes_for_miq_report(export_attributes)
      else
        export_attributes
      end

    export_attributes = handle_attributes(export_attributes)

    [{self.class.to_s => export_attributes}]
  end

  module ClassMethods
    def handle_miq_report_attributes_for_import(miq_schedule)
      group_description = miq_schedule['sched_action'][:options].delete(:miq_group_description)
      raise "Group description is empty from importing schedule" unless group_description

      miq_group = MiqGroup.find_by(:description => group_description)
      raise "Unable to find group #{group_description}" unless miq_group

      miq_schedule['sched_action'][:options][:miq_group_id] = miq_group.id
      miq_schedule
    end

    def import_from_hash(miq_schedule, options = nil)
      miq_schedule = handle_miq_report_attributes_for_import(miq_schedule) if miq_schedule["resource_type"] == "MiqReport"

      input_userid = options&.dig(:userid) || miq_schedule&.dig('userid')
      if input_userid && input_userid != 'system'
        miq_schedule['userid'] = User.find_by(:userid => input_userid)&.userid
        raise _("User #{input_userid} not found") unless miq_schedule['userid']
      end

      new_or_existing_schedule = MiqSchedule.where(:name => miq_schedule["name"], :resource_type => miq_schedule["resource_type"]).first_or_initialize

      filter_resource_name = miq_schedule.delete("filter_resource_name")

      miq_search = miq_schedule.delete("MiqSearchContent")
      file_depot = miq_schedule.delete("FileDepotContent")
      resource_name = miq_schedule.delete("resource_name")

      was_new_record = new_or_existing_schedule.new_record?
      new_or_existing_schedule.update(miq_schedule)

      if new_or_existing_schedule
        filter =
          if miq_schedule["resource_type"] == "MiqReport" || miq_schedule["resource_type"] == "MiqWidget"
            resource = miq_schedule["resource_type"].safe_constantize.find_by(:name => filter_resource_name)
            raise "Unable to find resource used in filter #{filter_resource_name}. Please add/update :filter_resource_name attribute in yaml of #{miq_schedule["resource_type"]}" unless resource

            MiqExpression.new("=" => {"field" => "#{miq_schedule["resource_type"]}-id", "value" => resource.id})
          else
            miq_schedule['filter']
          end

        schedule_attributes = {:filter => filter}

        if miq_search
          search = MiqSearch.where(miq_search[0]['MiqSearch']).first_or_create
          schedule_attributes[:miq_search_id] = search.id
        end

        if file_depot
          authentication_content = file_depot[0].values[0].delete("AuthenticationsContent")
          fd = FileDepot.where(file_depot[0].values[0]).first_or_create

          authentication_content[0].each do |auth|
            x = auth.values[0]
            x['resource'] = fd

            group_description = x.delete('miq_group_description')
            miq_group = MiqGroup.find_by(:description => group_description) || User.find_by(:userid=>'admin').current_group
            x['miq_group_id'] = miq_group.id

            tenant_name = x.delete('tenant_name')
            tenant = Tenant.find_by(:name => tenant_name) || Tenant.tenant_root
            x['tenant_id'] = tenant.id

            Authentication.where(x).first_or_create
          end
          new_or_existing_schedule.file_depot_id = fd.id
        end

        if resource_name
          schedule_resource = miq_schedule["resource_type"].safe_constantize.find_by(:name => resource_name)
          schedule_attributes['resource_id'] = schedule_resource.id if schedule_resource
        end

        new_or_existing_schedule.update(schedule_attributes)
      end

      status = :add
      message = "Imported #{miq_schedule["resource_type"]} Schedule: [#{new_or_existing_schedule["name"]}]"
      if new_or_existing_schedule.errors.messages.present?
        status = :error
        message = new_or_existing_schedule.errors.full_messages.join(', ')
      elsif !was_new_record
        status = :update
        message = "Updated #{miq_schedule["resource_type"]} Schedule: [#{new_or_existing_schedule["name"]}]"
      end

      return new_or_existing_schedule, {:message => message, :level => :info, :status => status}
    end
  end
end
