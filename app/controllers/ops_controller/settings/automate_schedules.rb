module OpsController::Settings::AutomateSchedules
  extend ActiveSupport::Concern

  def automate_schedules_set_vars
    schedule = params[:id] == "new" ? MiqSchedule.new : MiqSchedule.find_by(:id => params[:id])
    automate_request = fetch_automate_request_vars(schedule)

    render :json => {
      :starting_object => automate_request[:starting_object],
      :instance_names  => automate_request[:instance_names],
      :instance_name   => automate_request[:instance_name],
      :object_message  => automate_request[:object_message],
      :object_request  => automate_request[:object_request],
      :target_class    => automate_request[:target_class],
      :target_classes  => automate_request[:target_classes],
      :target_id       => automate_request[:target_id],
      :attrs           => automate_request[:attrs]
    }
  end

  def fetch_target_ids
    targets = Rbac.filtered(params[:target_class]).select(:id, :name)
    unless targets.nil?
      targets = targets.sort_by { |t| t.name.downcase }.collect { |t| [t.name, t.id.to_s] }
      target_id = ""
    end

    render :json => {
      :target_id => target_id,
      :targets   => targets
    }
  end

  def fetch_automate_request_vars(schedule)
    automate_request = {}
    # incase changing type of schedule
    filter = schedule.filter && schedule.filter.kind_of?(Hash) ? schedule.filter : {:uri_parts => {}, :parameters => {}}
    filter[:parameters].symbolize_keys!
    automate_request[:starting_object] = filter[:uri_parts][:namespace] || "SYSTEM/PROCESS"
    matching_instances = MiqAeClass.find_distinct_instances_across_domains(current_user,
                                                                           automate_request[:starting_object])

    automate_request[:instance_names] = matching_instances.collect(&:name).sort_by(&:downcase)
    automate_request[:instance_name]  = filter[:parameters][:instance_name] || "Request"
    automate_request[:object_message] = filter[:parameters][:object_message] || "create"
    automate_request[:object_request] = filter[:parameters][:request] || ""
    automate_request[:target_class]   = filter[:parameters][:target_class] || nil
    automate_request[:target_classes] = {}
    CustomButton.button_classes.each { |db| automate_request[:target_classes][db] = ui_lookup(:model => db) }
    automate_request[:target_classes] = Array(automate_request[:target_classes].invert).sort
    if automate_request[:target_class]
      targets = Rbac.filtered(automate_request[:target_class]).select(:id, :name)
      automate_request[:targets] = targets.sort_by { |t| t.name.downcase }.collect { |t| [t.name, t.id.to_s] }
    end
    automate_request[:target_id]      = filter[:parameters][:target_id] || ""
    automate_request[:attrs]          = filter[:parameters][:attrs] || []

    if automate_request[:attrs].empty?
      AE_MAX_RESOLUTION_FIELDS.times { automate_request[:attrs].push([]) }
    else
      # add empty array if @resolve[:new][:attrs] length is less than AE_MAX_RESOLUTION_FIELDS
      len = automate_request[:attrs].length
      AE_MAX_RESOLUTION_FIELDS.times { automate_request[:attrs].push([]) if len < AE_MAX_RESOLUTION_FIELDS }
    end
    automate_request
  end
end
