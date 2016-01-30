class MiqTaskController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    @tabform = nil
    @tabform ||= "tasks_1" if role_allows(:feature => "job_my_smartproxy")
    @tabform ||= "tasks_2" if role_allows(:feature => "miq_task_my_ui")
    @tabform ||= "tasks_3" if role_allows(:feature => "job_all_smartproxy")
    @tabform ||= "tasks_4" if role_allows(:feature => "miq_task_all_ui")
    jobs
    render :action => "jobs"
  end

  # New tab was pressed
  def change_tab
    @tabform = "tasks_#{params[:tab]}"
    jobs
    render :action => "jobs"
  end

  def build_jobs_tab
    @pp_choices = PPCHOICES2  # Get special pp choices for jobs/tasks lists
    @settings[:perpage][:job_task] ||= 50       # Default to 50 per page until changed
    @tasks_options = HashWithIndifferentAccess.new if @tasks_options.blank?
    @tasks_options[:zones] = Zone.all.collect { |z| z.name unless z.miq_servers.blank? }.compact
    tasks_set_default_options if @tasks_options[@tabform].blank?

    if role_allows(:feature => "job_my_smartproxy")
      @tabs ||= [["1", ""]]
      @tabs.push(["1", "My VM Analysis Tasks"])
    end
    if role_allows(:feature => "miq_task_my_ui")
      @tabs ||= [["2", ""]]
      @tabs.push(["2", "My Other UI Tasks"])
    end
    if role_allows(:feature => "job_all_smartproxy")
      @tabs ||= [["3", ""]]
      @tabs.push(["3", "All VM Analysis Tasks"])
    end
    if role_allows(:feature => "miq_task_all_ui")
      @tabs ||= [["4", ""]]
      @tabs.push(["4", "All Other Tasks"])
    end

    case @tabform
    when "tasks_1"
      @tabs[0][0] = "1"
    when "tasks_2"
      @tabs[0][0] = "2"
    when "tasks_3"
      @tabs[0][0] = "3"
    when "tasks_4"
      @tabs[0][0] = "4"
    end
  end

  # Show job list for the current user
  def jobs
    build_jobs_tab
    @title = "Tasks for #{current_user.name}"
    @breadcrumbs = []
    @lastaction = "jobs"

    @edit = {}
    @edit[:opts] = {}
    @edit[:opts] = copy_hash(@tasks_options[@tabform])   # Backup current settings

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] ||
                                       params[:entry] || params[:sort_choice] || params[:user_choice])
      get_jobs(tasks_condition(@tasks_options[@tabform]))
      render :update do |page|
        page.replace_html("gtl_div", :partial => "layouts/gtl", :locals => {:action_url => @lastaction})
        page.replace_html("paging_div", :partial => 'layouts/pagingcontrols',
                                        :locals  => {:pages      => @pages,
                                                     :action_url => @lastaction,
                                                     :db         => @view.db,
                                                     :headers    => @view.headers})
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    else                      # Came in from non-ajax, just get the jobs
      get_jobs(tasks_condition(@tasks_options[@tabform]))
    end
  end

  def get_jobs(conditions)
    @lastaction = "jobs"

    if @tabform == "tasks_1"
      @layout = "my_tasks"
      @view, @pages = get_view(Job, :conditions => conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => "My VM Analysis Tasks", :url => "/miq_task/index?jobs_tab=tasks")

    elsif @tabform == "tasks_2"
      # My UI Tasks
      @layout = "my_ui_tasks"
      @view, @pages = get_view(MiqTask, :conditions => conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => "My Other UI Tasks", :url => "/miq_task/index?jobs_tab=tasks")

    elsif @tabform == "tasks_3" || @tabform == "alltasks_1"
      @layout = "all_tasks"
      @view, @pages = get_view(Job, :conditions => conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => "All VM Analysis Tasks", :url => "/miq_task/index?jobs_tab=alltasks")
      @user_names = Job.distinct("userid").pluck("userid").delete_if(&:blank?)

    elsif @tabform == "tasks_4" || @tabform == "alltasks_2"
      # All UI Tasks
      @layout = "all_ui_tasks"
      @view, @pages = get_view(MiqTask, :conditions => conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => "All Other Tasks", :url => "/miq_task/index?jobs_tab=alltasks")
      @user_names = MiqTask.distinct("userid").pluck("userid").delete_if(&:blank?)
    end
  end

  # Cancel a single selected job
  def canceljobs
    assert_privileges("miq_task_canceljob")
    job_id = find_checked_items
    if job_id.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "miq_task"),
                                                              :task  => "cancellation"}, :error)
    end
    case @layout
    when "my_tasks", "all_tasks"
      db_class = Job
    when "my_ui_tasks", "all_ui_tasks"
      db_class = MiqTask
    end
    job = db_class.find_by_id(job_id)
    if job["state"].downcase == "finished"
      add_flash(_("Finished Task cannot be cancelled"), :error)
    else
      process_jobs(job_id, "cancel")  unless job_id.empty?
      add_flash(_("The selected Task was cancelled"), :error) if @flash_array.nil?
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # Delete all selected or single displayed job(s)
  def deletejobs
    assert_privileges("miq_task_delete")
    job_ids = find_checked_items
    if job_ids.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "miq_task"),
                                                              :task  => "deletion"}, :error)
    else
      case @layout
      when "my_tasks", "all_tasks"
        db_class = Job
      when "my_ui_tasks", "all_ui_tasks"
        db_class = MiqTask
      end
      db_class.delete_by_id(job_ids)
      AuditEvent.success(:userid       => session[:userid],
                         :event        => "Delete selected tasks",
                         :message      => "Delete started for record ids: #{job_ids.inspect}",
                         :target_class => db_class.base_class.name)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") %
                  {:task        => "Delete",
                   :count_model => pluralize(job_ids.length, ui_lookup(:tables => "miq_task"))}) if @flash_array.nil?
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # Delete all finished job(s)
  def deletealljobs
    assert_privileges("miq_task_deleteall")
    job_ids = []
    session[:view].table.data.each do |rec|
      job_ids.push(rec["id"])
    end
    if job_ids.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "miq_task"),
                                                              :task  => "deletion"}, :error)
    else
      case @layout
      when "my_tasks", "all_tasks"
        db_class = Job
      when "my_ui_tasks", "all_ui_tasks"
        db_class = MiqTask
      end
      db_class.delete_by_id(job_ids)
      AuditEvent.success(:userid       => session[:userid],
                         :event        => "Delete all finished tasks",
                         :message      => "Delete started for record ids: #{job_ids.inspect}",
                         :target_class => db_class.base_class.name)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") %
                  {:task        => "Delete",
                   :count_model => pluralize(job_ids.length, ui_lookup(:tables => "miq_task"))})  if @flash_array.nil?
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # Delete all job(s) older than selected job(s)
  def deleteolderjobs
    assert_privileges("miq_task_deleteolder")
    jobid = find_checked_items
    case @layout
    when "my_tasks", "all_tasks"
      db_class = Job
    when "my_ui_tasks", "all_ui_tasks"
      db_class = MiqTask
    end
    # fetching job record for the selected job
    job = db_class.find_by_id(jobid)
    if job
      db_class.delete_older(job.updated_on, tasks_condition(@tasks_options[@tabform], false))
      message = "Delete started for records older than #{job.updated_on}, conditions: #{@tasks_options[@tabform].inspect}"
      AuditEvent.success(:userid       => session[:userid],
                         :event        => "Delete older tasks",
                         :message      => message,
                         :target_class => db_class.base_class.name)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") %
                  {:task        => "Delete all older Tasks",
                   :count_model => pluralize(jobid.length, ui_lookup(:tables => "miq_task"))})
    else
      add_flash(_("The selected job no longer exists, Delete all older Tasks was not completed"), :warning)
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  def process_jobs(jobs, task)
    case @layout
    when "my_tasks", "all_tasks"
      db_class = Job
    when "my_ui_tasks", "all_ui_tasks"
      db_class = MiqTask
    end
    db_class.find_all_by_id(jobs, :order => "lower(name)").each do |job|
      id = job.id
      job_name = job.name
      if task == "destroy"
        audit = {:event        => "jobs_record_delete",
                 :message      => "[#{job_name}] Record deleted",
                 :target_id    => id,
                 :target_class => db_class.base_class.name,
                 :userid       => session[:userid]}
      end
      begin
        job.send(task.to_sym) if job.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model => ui_lookup(:model => "MiqTask"),
                                                                         :name  => job_name,
                                                                         :task  => task} << bang.message, :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => ui_lookup(:tables => "miq_task"),
                                                                    :name  => job_name}, :error)
        else
          add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record => job_name, :task => task})
        end
      end
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    deletejobs      if params[:pressed] == "miq_task_delete"
    deletealljobs   if params[:pressed] == "miq_task_deleteall"
    deleteolderjobs if params[:pressed] == "miq_task_deleteolder"
    canceljobs      if params[:pressed] == "miq_task_canceljob"
    reloadjobs      if params[:pressed] == "miq_task_reload"

    render :update do |page|                    # Use RJS to update the display
      unless @refresh_partial.nil?
        if @refresh_div == "flash_msg_div"
          page << "miqSetButtons(0, 'center_tb');"                             # Reset the center toolbar
          page.replace(@refresh_div, :partial => @refresh_partial)
        else
          page << "miqSetButtons(0, 'center_tb');"                             # Reset the center toolbar
          page.replace_html("main_div", :partial => @refresh_partial)
          page.replace_html("paging_div", :partial => 'layouts/pagingcontrols',
                                          :locals  => {:pages      => @pages,
                                                       :action_url => @lastaction,
                                                       :db         => @view.db,
                                                       :headers    => @view.headers})
        end
      end
    end
  end

  # Gather any changed options
  def tasks_change_options
    @edit = session[:edit]
    @edit[:opts][:zone] = params[:chosen_zone] if params[:chosen_zone]
    @edit[:opts][:user_choice] = params[:user_choice] if params[:user_choice]
    @edit[:opts][:time_period] = params[:time_period].to_i if params[:time_period]
    @edit[:opts][:queued] = params[:queued] == "1" ? params[:queued] : nil if params[:queued]
    @edit[:opts][:ok] = params[:ok] == "1" ? params[:ok] : nil if params[:ok]
    @edit[:opts][:error] = params[:error] == "1" ? params[:error] : nil if params[:error]
    @edit[:opts][:warn] = params[:warn] == "1" ? params[:warn] : nil if params[:warn]
    @edit[:opts][:running] = params[:running] == "1" ? params[:running] : nil if params[:running]
    @edit[:opts][:state_choice] = params[:state_choice] if params[:state_choice]

    render :update do |page|
      page << javascript_for_miq_button_visibility(@tasks_options[@tabform] != @edit[:opts])
    end
  end

  # Refresh the display with the chosen filters
  def tasks_button
    @edit = session[:edit]
    if params[:button] == "apply"
      @tasks_options[@tabform] = copy_hash(@edit[:opts]) # Copy the latest changed options
    elsif params[:button] == "reset"
      @edit[:opts] = copy_hash(@tasks_options[@tabform]) # Reset to the saved options
    elsif params[:button] == "default"
      tasks_set_default_options
      @edit[:opts] = copy_hash(@tasks_options[@tabform]) # Backup current settings
    end

    get_jobs(tasks_condition(@tasks_options[@tabform]))  # Get the jobs based on the latest options
    @pp_choices = PPCHOICES2                             # Get special pp choices for jobs/tasks lists

    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "miqSetButtons(0, 'center_tb');"                             # Reset the center toolbar
      page.replace("main_div", :partial => "layouts/tasks")
      page.replace_html("paging_div", :partial => 'layouts/pagingcontrols',
                                      :locals  => {:pages      => @pages,
                                                   :action_url => @lastaction,
                                                   :db         => @view.db,
                                                   :headers    => @view.headers})
      page << "miqSparkle(false);"
    end
  end

  private ############################

  # Set all task options to default
  def tasks_set_default_options
    @tasks_options[@tabform] = {
      :ok           => true,
      :queued       => true,
      :error        => true,
      :warn         => true,
      :running      => true,
      :states       => %w(tasks_1 tasks_3).include?(@tabform) ? SP_STATES : UI_STATES,
      :state_choice => "all",
      :time_period  => 0,
    }

    @tasks_options[@tabform][:zone]        = "<all>" if %w(tasks_1 tasks_3).include?(@tabform)
    @tasks_options[@tabform][:user_choice] = "all"   if %w(tasks_1 tasks_4).include?(@tabform)
  end

  # Create a condition from the passed in options
  def tasks_condition(opts, use_times = true)
    cond = [[]]
    cond = add_to_condition(cond, *build_query_for_userid(opts))

    if !opts[:ok] && !opts[:queued] && !opts[:error] && !opts[:warn] && !opts[:running]
      query, values = build_query_for_status_none_selected
    else
      query, *values = build_query_for_status(opts)
    end
    cond = add_to_condition(cond, query, values)

    # Add time condition
    cond = add_to_condition(cond, *build_query_for_time_period(opts)) if use_times

    # Add zone condition
    cond = add_to_condition(cond, *build_query_for_zone(opts)) if vm_analysis_task? && opts[:zone] != "<all>"

    cond = add_to_condition(cond, *build_query_for_state(opts)) if opts[:state_choice] != "all"

    cond[0] = "#{cond[0].join(" AND ")}"
    cond.flatten
  end

  def add_to_condition(cond, query, values)
    cond[0] << query unless query.nil?
    cond << values unless values.nil?
    cond
  end

  def build_query_for_userid(opts)
    return ["userid=?", session[:userid]] if %w(tasks_1 tasks_2).include?(@tabform)
    return ["userid=?", opts[:user_choice]] if opts[:user_choice] && opts[:user_choice] != "all"
    return nil, nil
  end

  def build_query_for_status(opts)
    cond = [[]]
    [:queued, :ok, :error, :warn, :running].each do |st|
      cond = add_to_condition(cond, *send("build_query_for_" + st.to_s)) if opts[st]
    end

    cond[0] = "(#{cond[0].join(" OR ")})"
    cond
  end

  def build_query_for_queued
    ["(state=? OR state=?)", %w(waiting_to_start Queued)]
  end

  def build_query_for_ok
    build_query_for_status_completed("ok")
  end

  def build_query_for_error
    build_query_for_status_completed("error")
  end

  def build_query_for_warn
    build_query_for_status_completed("warn")
  end

  def build_query_for_status_completed(status)
    return ["(state=? AND status=?)", ["finished", status]] if vm_analysis_task?
    ["(state=? AND status=?)", ["Finished", status.capitalize]]
  end

  def build_query_for_running
    return ["(state!=? AND state!=? AND state!=?)", %w(finished waiting_to_start queued)] if vm_analysis_task?
    ["(state!=? AND state!=? AND state!=?)", %w(Finished waiting_to_start Queued)]
  end

  def build_query_for_status_none_selected
    return ["(status!=? AND status!=? AND status!=? AND state!=? AND state!=?)",
            %w(ok error warn finished waiting_to_start)] if vm_analysis_task?
    ["(status!=? AND status!=? AND status!=? AND state!=? AND state!=?)", %w(Ok Error Warn Finished Queued)]
  end

  def build_query_for_time_period(opts)
    t = format_timezone(opts[:time_period].to_i != 0 ? opts[:time_period].days.ago : Time.now, Time.zone, "raw")
    ["updated_on>=? AND updated_on<=?", [t.beginning_of_day, t.end_of_day]]
  end

  def build_query_for_zone(opts)
    ["zone=?", opts[:zone]]
  end

  def build_query_for_state(opts)
    ["state=?", opts[:state_choice]]
  end

  def vm_analysis_task?
    %w(tasks_1 tasks_3).include?(@tabform)
  end

  def reloadjobs
    assert_privileges("miq_task_reload")
    jobs
    @refresh_partial = "layouts/tasks"
  end

  def get_layout
    %w(my_tasks my_ui_tasks all_tasks all_ui_tasks).include?(session[:layout]) ? session[:layout] : "my_tasks"
  end

  def get_session_data
    @layout        = get_layout
    @jobs_tab      = session[:jobs_tab] if session[:jobs_tab]
    @tabform       = session[:tabform]  if session[:tabform]
    @lastaction    = session[:jobs_lastaction]
    @tasks_options = session[:tasks_options] || ""
  end

  def set_session_data
    session[:jobs_tab]            = @jobs_tab
    session[:tabform]             = @tabform
    session[:layout]              = @layout
    session[:jobs_lastaction]     = @lastaction
    session[:tasks_options]       = @tasks_options unless @tasks_options.nil?
  end
end
