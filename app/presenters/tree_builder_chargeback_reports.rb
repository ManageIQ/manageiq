class TreeBuilderChargebackReports < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :leaf => "MiqReportResult"}
  end

  def set_locals_for_render
    locals = super
    temp = {
      :id_prefix => "cbrpt_",
      :autoload  => true
    }
    locals.merge!(temp)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    items = MiqReportResult.auto_generated.select("miq_report_id, name").group("miq_report_id, name").where(
      :db     => "Chargeback",
      :userid => User.current_user.userid)

    if count_only
      items.length
    else
      objects = []
      items.sort_by { |item| item.name.downcase }.each_with_index do |item, idx|
        objects.push(
          :id    => "#{to_cid(item.miq_report_id)}-#{idx}",
          :text  => item.name,
          :image => "report",
          :tip   => item.name
        )
      end
      objects
    end
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
    objects = MiqReportResult.auto_generated.where(
      :miq_report_id => from_cid(object[:id].split('-').first),
      :userid        => User.current_user.userid
    ).order("created_on DESC").select("id, miq_report_id, name, last_run_on, miq_task_id")

    count_only_or_objects(count_only, objects, "name")
  end
end
