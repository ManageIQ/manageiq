class MiqProxyController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    if role_allows(:feature=>"miq_proxy_show_list") && !params[:jobs_tab]
      redirect_to :action => 'show_list'
    else
      @tabform = nil
      @tabform ||= "tasks_1" if role_allows(:feature=>"job_my_smartproxy")
      @tabform ||= "tasks_2" if role_allows(:feature=>"miq_task_my_ui")
      @tabform ||= "tasks_3" if role_allows(:feature=>"job_all_smartproxy") && role_allows(:feature=>"job_all_smartproxy")
      @tabform ||= "tasks_4" if role_allows(:feature=>"miq_task_all_ui") && role_allows(:feature=>"miq_task_all_ui")
      jobs
      render :action=>"jobs"
    end
  end

  # New tab was pressed
  def change_tab
    @tabform = "tasks_" + params[:tab]
    jobs
    render :action=>"jobs"
  end

  def build_jobs_tab
    @pp_choices = PPCHOICES2  # Get special pp choices for jobs/tasks lists
    @settings[:perpage][:job_task] ||= 50       # Default to 50 per page until changed
    @tasks_options = HashWithIndifferentAccess.new if @tasks_options.blank?
    @tasks_options[:zones] = Zone.all.collect{|z| z.name unless z.miq_servers.blank?}.compact
#   session[:user_choice] = "all"
#   sm_states = [["Initializing","initializing"], ["Waiting to Start","waiting_to_start"], ["Cancelling","cancelling"], ["Aborting","aborting"],
#       ["Finished","finished"],["Snapshot Create","snapshot_create"], ["Scanning","scanning"], ["Snapshot Delete","snapshot_delete"],
#       ["Synchronizing","synchronizing"], ["Deploy Smartproxy","deploy_smartproxy"]]
#   ui_states = [["Initialized","Initialized"], ["Queued","Queued"],["Active","Active"],["Finished","Finished"]]
#
    tasks_set_default_options if @tasks_options[@tabform].blank?

    if role_allows(:feature=>"job_my_smartproxy")
      @tabs ||= [ ["1", ""] ]
      @tabs.push( ["1", "My VM Analysis Tasks"] )
    end
    if role_allows(:feature=>"miq_task_my_ui")
      @tabs ||= [ ["2", ""] ]
      @tabs.push( ["2", "My Other UI Tasks"] )
    end
    if role_allows(:feature=>"job_all_smartproxy") && role_allows(:feature=>"job_all_smartproxy")
      @tabs ||= [ ["3", ""] ]
      @tabs.push( ["3", "All VM Analysis Tasks"] )
    end
    if role_allows(:feature=>"miq_task_all_ui") && role_allows(:feature=>"miq_task_all_ui")
      @tabs ||= [ ["4", ""] ]
      @tabs.push( ["4", "All Other Tasks"] )
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
    @title = "Tasks for #{session[:username]}"
    @breadcrumbs = Array.new
    @lastaction = "jobs"

    @edit = Hash.new
    @edit[:opts] = Hash.new
    @edit[:opts] = copy_hash(@tasks_options[@tabform])   # Backup current settings

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:user_choice])
      get_jobs(tasks_condition(@tasks_options[@tabform]))
      render :update do |page|
        page.replace_html("gtl_div", :partial=>"layouts/gtl", :locals=>{:action_url=>@lastaction})
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    else                      # Came in from non-ajax, just get the jobs
      get_jobs(tasks_condition(@tasks_options[@tabform]))
    end
  end

  def get_jobs(conditions)
    if @tabform == "tasks_1"
      #My SmartProxy Tasks
      @layout = "my_tasks"
      @lastaction = "jobs"
      @view, @pages = get_view(Job, :conditions=>conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb( {:name=>"My VM Analysis Tasks", :url=>"/miq_proxy/index?jobs_tab=tasks"})

    elsif @tabform == "tasks_2"
      #My UI Tasks
      @layout = "my_ui_tasks"
      @lastaction = "ui_jobs"
      @view, @pages = get_view(MiqTask, :conditions=>conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb( {:name=>"My Other UI Tasks", :url=>"/miq_proxy/index?jobs_tab=tasks"})

    elsif @tabform == "tasks_3" || @tabform == "alltasks_1"
      #All SmartProxy Tasks
      @layout = "all_tasks"
      @lastaction = "all_jobs"
      @view, @pages = get_view(Job, :conditions=>conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb( {:name=>"All VM Analysis Tasks", :url=>"/miq_proxy/index?jobs_tab=alltasks"} )
      @user_names = []
      job_recs = Job.all(:select=>"userid", :group=>"userid")
      job_recs.each do |j|
        @user_names.push(j.userid) unless j.userid.blank?
      end

    elsif @tabform == "tasks_4" || @tabform == "alltasks_2"
      #All UI Tasks
      @layout = "all_ui_tasks"
      @lastaction = "all_ui_jobs"
      @view, @pages = get_view(MiqTask, :conditions=>conditions)  # Get the records (into a view) and the paginator
      drop_breadcrumb( {:name=>"All Other Tasks", :url=>"/miq_proxy/index?jobs_tab=alltasks"} )
      @user_names = []
      job_recs = MiqTask.all(:select=>"userid", :group=>"userid")
      job_recs.each do |j|
        @user_names.push(j.userid) unless j.userid.blank?
      end
    end
  end

  # Cancel a single selected job
  def canceljobs
    assert_privileges("miq_task_canceljob")
    job_id = Array.new
    job_id = find_checked_items
    if job_id.empty?
      add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>"miq_task"), :task=>"cancellation"), :error)
    end
    case @layout
      when "my_tasks", "all_tasks"
        db_class = Job
      when "my_ui_tasks","all_ui_tasks"
        db_class = MiqTask
    end
    job = db_class.find_by_id(job_id)
    if job["state"].downcase == "finished"
      add_flash(I18n.t("flash.smartproxy.finish_task_cancel"), :error)
    else
      process_jobs(job_id, "cancel")  if ! job_id.empty?
      add_flash(I18n.t("flash.smartproxy.selected_task_cancelled"), :error) if @flash_array == nil
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # Delete all selected or single displayed job(s)
  def deletejobs
    assert_privileges("miq_task_delete")
    job_ids = Array.new
    job_ids = find_checked_items
    if job_ids.empty?
      add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>"miq_task"), :task=>"deletion"), :error)
    else
      case @layout
        when "my_tasks", "all_tasks"
          db_class = Job
        when "my_ui_tasks","all_ui_tasks"
          db_class = MiqTask
      end
      db_class.delete_by_id(job_ids)
      AuditEvent.success(:userid=>session[:userid],:event=>"Delete selected tasks",
          :message=>"Delete started for record ids: #{job_ids.inspect}",
          :target_class=>db_class.base_class.name)
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Delete", :count_model=>pluralize(job_ids.length,ui_lookup(:tables=>"miq_task")))) if @flash_array == nil
    end
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # Delete all finished job(s)
  def deletealljobs
    assert_privileges("miq_task_deleteall")
    job_ids = Array.new
    session[:view].table.data.each do |rec|
      job_ids.push(rec["id"])
    end
    if job_ids.empty?
      add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>"miq_task"), :task=>"deletion"), :error)
    else
      case @layout
        when "my_tasks", "all_tasks"
          db_class = Job
        when "my_ui_tasks","all_ui_tasks"
          db_class = MiqTask
      end
      db_class.delete_by_id(job_ids)
      AuditEvent.success(:userid=>session[:userid],:event=>"Delete all finished tasks",
          :message=>"Delete started for record ids: #{job_ids.inspect}",
          :target_class=>db_class.base_class.name)
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Delete", :count_model=>pluralize(job_ids.length,ui_lookup(:tables=>"miq_task"))))  if @flash_array == nil
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
      when "my_ui_tasks","all_ui_tasks"
        db_class = MiqTask
    end
    # fetching job record for the selected job
    job = db_class.find_by_id(jobid)
    if job
      if @layout.starts_with?("my_")
        uid = session[:userid]
      else
        uid = @tasks_options[@tabform][:user_choice].blank? ? nil : @tasks_options[@tabform][:user_choice]
      end
      db_class.delete_older(job.updated_on, tasks_condition(@tasks_options[@tabform], false))
      AuditEvent.success(:userid=>session[:userid],:event=>"Delete older tasks",
          :message=>"Delete started for records older than #{job.updated_on.to_s}, conditions: #{@tasks_options[@tabform].inspect}",
          :target_class=>db_class.base_class.name)
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Delete all older Tasks", :count_model=>pluralize(jobid.length,ui_lookup(:tables=>"miq_task"))))
    else
      add_flash(I18n.t("flash.smartproxy.delete_older_not_completed"), :warning)
    end

    jobs
    @refresh_partial = "layouts/tasks"
  end

  def process_jobs(jobs, task)
    case @layout
      when "my_tasks", "all_tasks"
        db_class = Job
      when "my_ui_tasks","all_ui_tasks"
        db_class = MiqTask
    end
    db_class.find_all_by_id(jobs, :order => "lower(name)").each do |job|
      id = job.id
      job_name = job.name
      if task == "destroy"
        audit = {:event=>"jobs_record_delete", :message=>"[#{job_name}] Record deleted", :target_id=>id, :target_class=>db_class.base_class.name, :userid => session[:userid]}
      end
      begin
        job.send(task.to_sym) if job.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(I18n.t("flash.record.error_during_task", :model=>ui_lookup(:model=>"MiqProxy"), :name=>job_name, :task=>task) << bang.message, :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(I18n.t("flash.record.deleted", :model=>ui_lookup(:tables=>"miq_task"), :name=>job_name), :error)
        else
          add_flash(I18n.t("flash.record.task_initiated_for_record", :record=>job_name, :task=>task))
        end
      end
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms","hosts","storages"].include?(@display)  # Were we displaying vms/hosts/storages

    edit_record  if params[:pressed] == "host_edit"
    scanhosts if params[:pressed] == "host_scan"
    refreshhosts   if params[:pressed] == "host_refresh"
    tag(Host) if params[:pressed] == "host_tag"
    deletehosts if params[:pressed] == "host_delete"
    assign_policies(Host) if params[:pressed] == "host_protect"

    refreshstorage if params[:pressed] == "storage_refresh"
    tag(Storage) if params[:pressed] == "storage_tag"

    pfx = pfx_for_vm_button_pressed(params[:pressed])
    process_vm_buttons(pfx)

    edit_record if params[:pressed] == "miq_proxy_edit"
    deploy_build  if params[:pressed] == "miq_proxy_deploy"

    deletejobs if params[:pressed] == "miq_task_delete"
    deletealljobs if params[:pressed] == "miq_task_deleteall"
    deleteolderjobs if params[:pressed] == "miq_task_deleteolder"
    canceljobs if params[:pressed] == "miq_task_canceljob"
    reloadjobs if params[:pressed] == "miq_task_reload"

    # Control transferred to another screen, so return
    return if ["miq_proxy_deploy","host_tag", "#{pfx}_policy_sim", "host_scan",
               "host_refresh","host_protect","#{pfx}_compare", "#{pfx}_tag",
               "#{pfx}_protect","#{pfx}_scan","#{pfx}_retire","#{pfx}_ownership",
               "#{pfx}_right_size","storage_tag"].include?(params[:pressed]) && @flash_array == nil

    if !["#{pfx}_edit","host_edit","miq_proxy_edit","delete","deleteall",
         "deleteolder","canceljob","miq_task_delete","miq_task_deleteall",
         "miq_task_deleteolder","miq_task_canceljob","miq_task_reload",
         "miq_proxy_deploy","#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate",
         "#{pfx}_publish"].include?(params[:pressed])
      @refresh_div = "main_div"
      @refresh_partial = "layouts/gtl"
      show                                                        # Handle EMS buttons
    end

    if !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(I18n.t("flash.button.not_implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit")
      render :update do |page|
        page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
      end
    elsif ["#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    else
      render :update do |page|                    # Use RJS to update the display
        if @refresh_partial != nil
          if @refresh_div == "flash_msg_div"
            page << "miqSetButtons(0,'center_tb');"                             # Reset the center toolbar
            page.replace(@refresh_div, :partial=>@refresh_partial)
          else
            page << "miqSetButtons(0,'center_tb');"                             # Reset the center toolbar
            if @display == "vms"  # If displaying vms, action_url s/b show
              page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@miq_proxy.id}"})
            else
              page.replace_html("main_div", :partial=>@refresh_partial)
            end
          end
        end
      end
    end
  end

  # Show the main SmartProxy list view
  def show_list
    @layout = "miq_proxy"
    process_show_list
  end

  # show a single item from a detail list
  def show
    @display = params[:display] || "main" unless control_selected?
    identify_miq_proxy
    return if record_no_longer_exists?(@miq_proxy)

    drop_breadcrumb( {:name=>"SmartProxies", :url=>"/miq_proxy/show_list?page=#{@current_page}&refresh=y"}, true )
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@miq_proxy)
      drop_breadcrumb( {:name=>"SmartProxy: " + @miq_proxy.name, :url=>"/miq_proxy/show/#{@miq_proxy.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
      @layout = "miq_proxy"

    when "hosts"
      drop_breadcrumb( {:name=>@miq_proxy.name+" (All Managed Hosts)", :url=>"/miq_proxy/show/#{@miq_proxy.id}?display=hosts"} )
      @view, @pages = get_view(Host, :parent=>@miq_proxy) # Get the records (into a view) and the paginator
      @showtype = "hosts"
      @gtl_url = "/miq_proxy/show/" << @miq_proxy.id.to_s << "?"
      if @view.extras[:total_count] && @view.extras[:total_count] > @miq_proxy.hosts.length
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @miq_proxy.hosts.length, "other Host") + " on this SmartProxy"
      end

    when "storages"
      drop_breadcrumb( {:name=>@miq_proxy.name+" (All Managed #{ui_lookup(:tables=>"storages")})", :url=>"/miq_proxy/show/#{@miq_proxy.id}?display=storages"} )
      @view, @pages = get_view(Storage, :parent=>@miq_proxy)  # Get the records (into a view) and the paginator
      @showtype = "storages"
      @gtl_url = "/miq_proxy/show/" << @miq_proxy.id.to_s << "?"
      if @view.extras[:total_count] && @view.extras[:total_count] > @miq_proxy.storages.length
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @miq_proxy.storages.length, "other " + ui_lookup(:table=>"storages")) + " on this SmartProxy"
      end

    when "miq_templates", "vms"
      title, kls = @display == "vms" ? ["VMs", Vm] : ["Templates", MiqTemplate]
      drop_breadcrumb( {:name=>@miq_proxy.name+" (All #{title})", :url=>"/miq_proxy/show/#{@miq_proxy.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent=>@miq_proxy)  # Get the records (into a view) and the paginator
      @showtype = @display
      @gtl_url = "/miq_proxy/show/" << @miq_proxy.id.to_s << "?"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this SmartProxy"
      end
    end
    @lastaction = "show"
    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def new
    assert_privileges("miq_proxy_new")
    @miq_proxy = MiqProxy.new
    set_form_vars
    @in_a_form = true
    drop_breadcrumb( {:name=>"Add New SmartProxy", :url=>"/miq_proxy/new"} )
  end

  def create
    assert_privileges("miq_proxy_new")
    return unless load_edit("proxy_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      render :update do |page|
        page.redirect_to :action=>'show_list', :flash_msg=>I18n.t("flash.add.cancelled",:model=>ui_lookup(:model=>"MiqProxy"))
      end
    when "add"
      add_miq_proxy = MiqProxy.new
      set_record_vars(add_miq_proxy)
      if valid_record?(add_miq_proxy) && add_miq_proxy.save
        Host.find_by_name(@edit[:new][:name]).miq_proxy = add_miq_proxy
        AuditEvent.success(build_created_audit(add_miq_proxy, @edit))
        render :update do |page|
          page.redirect_to :action=>'show_list', :flash_msg=>I18n.t("flash.add.added", :model=>ui_lookup(:model=>"MiqProxy"), :name=>add_miq_proxy.name)
        end
        return
      else
        @in_a_form = true
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        add_miq_proxy.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Add New SmartProxy", :url=>"/miq_proxy/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "validate"
      verify_miq_proxy = MiqProxy.new
      set_record_vars(verify_miq_proxy)
      @in_a_form = true
      begin
        verify_miq_proxy.verify_credentials
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(I18n.t("flash.credentials.validated"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def edit
    assert_privileges("miq_task_edit")
    identify_miq_proxy
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb( {:name=>"Edit SmartProxy '#{@miq_proxy.name}'", :url=>"/miq_proxy/edit/#{@miq_proxy.id}"} )
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("proxy_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
    end
  end

  def update
    assert_privileges("miq_proxy_edit")
    return unless load_edit("proxy_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      flash = I18n.t("flash.edit.cancelled", :model=>ui_lookup(:model=>"MiqProxy"), :name=>@miq_proxy.name)
      render :update do |page|
        page.redirect_to :action=>@lastaction, :id=>@miq_proxy.id, :display=>session[:miqproxy_display], :flash_msg=>flash
      end
    when "save"
      update_miq_proxy = find_by_id_filtered(MiqProxy, params[:id])
      set_record_vars(update_miq_proxy)
      if valid_record?(update_miq_proxy) && update_miq_proxy.save
        flash = I18n.t("flash.edit.saved", :model=>ui_lookup(:model=>"MiqProxy"), :name=>update_miq_proxy.name)
        AuditEvent.success(build_saved_audit(update_miq_proxy, @edit))
        if agent_settings_changed?
          audit = {:event=>"agent_settings_activate", :target_id=>update_miq_proxy.id, :target_class=>update_miq_proxy.class.base_class.name, :userid => session[:userid]}
          begin
          update_miq_proxy.change_agent_config          # Activate the new miq_proxy settings
          rescue StandardError=>bang
            add_flash(I18n.t("flash.smartproxy.settings_activation_error") << bang.message, :error)
            AuditEvent.failure(audit.merge(:message=>"[#{update_miq_proxy.name}] SmartProxy settings activation returned: #{bang}"))
          else
            add_flash(I18n.t("flash.smartproxy.new_settings_activated"))
            AuditEvent.success(audit.merge(:message=>"[#{update_miq_proxy.name}] SmartProxy settings have been activated"))
          end
        end
        session[:edit] = nil  # clean out the saved info
        render :update do |page|
          page.redirect_to :action=>'show', :id=>@miq_proxy.id.to_s, :flash_msg=>flash
        end
        return
      else
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        update_miq_proxy.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Edit SmartProxy '#{@miq_proxy.name}'", :url=>"/miq_proxy/edit/#{@miq_proxy.id}"} )
        @in_a_form = true
        session[:changed] = changed
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "reset"
      params[:edittype] = @edit[:edittype]    # remember the edit type
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'edit', :id=>@miq_proxy.id.to_s
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
      page << "miqSetButtons(0,'center_tb');"                             # Reset the center toolbar
      page.replace("main_div", :partial=>"layouts/tasks")
      page << "miqSparkle(false);"
    end
  end

  # Install/reinstall a SmartProxy build on the associated host
  def install_007
    identify_miq_proxy
    case params[:button]
    when "cancel"
      flash = I18n.t("flash.smartproxy.deploy_smaprtproxy_cancelled", :name=>@miq_proxy.host.name)
      redirect_to :action => @lastaction, :id=>@miq_proxy.id, :display=>"main", :flash_msg=>flash
    when "save"
      @edit = session[:edit]
      changed = (@edit[:new] != @edit[:current])
      audit = {:event=>"proxy_version_install", :target_id=>@miq_proxy.host.id, :target_class=>@miq_proxy.host.class.base_class.name, :userid => session[:userid]}
      begin
        if @miq_proxy.state == "on" || valid_credentials?
          if changed                                                                      # If credentials were changed
            set_host_credentials(@miq_proxy.host)                                         # Set/save the new credentials on the host
          end
          if @miq_proxy.state == "on"
            @miq_proxy.update_activate_agent_version(ProductUpdate.find(@edit[:install_build])) # Update and activate the agent sw on the host
          else
            @miq_proxy.deploy_agent_version(session[:userid], ProductUpdate.find(@edit[:install_build]))  # Deploy new agent w/host credentials
          end
        else
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          @in_a_form = true
          session[:changed] = changed
          @changed = true
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
          return
        end
      rescue StandardError=>bang
        flash = I18n.t("flash.error_during", :task=>"SmartProxy deploy") << bang.message; flash_error = true
        AuditEvent.failure(audit.merge(:message=>flash))
        render :update do |page|
          page.redirect_to :action => @lastaction, :id=>@miq_proxy.id, :display=>"main", :flash_msg=>flash, :flash_error=>true, :escape=>false
        end
      else
        flash = I18n.t("flash.smartproxy.deploy_smaprtproxy_initiated", :name=>@miq_proxy.host.name)
        AuditEvent.success(audit.merge(:message=>"[#{@miq_proxy.host.name}] Deploy of SmartProxy version initiated (version:[#{params[:install_build]}])"))
        render :update do |page|
          page.redirect_to :action => @lastaction, :id=>@miq_proxy.id, :display=>"main", :flash_msg=>flash, :escape=>false
        end
      end
    when "validate"
      @edit = session[:edit]
      creds = {}
      creds[:default] = {:userid=>@edit[:new][:default_userid],        :password=>@edit[:new][:default_password]}        unless @edit[:new][:default_userid].blank?
      creds[:remote]  = {:userid=>@edit[:new][:remote_userid], :password=>@edit[:new][:remote_password]} unless @edit[:new][:remote_userid].blank?
      creds[:ws]      = {:userid=>@edit[:new][:ws_userid],     :password=>@edit[:new][:ws_password]}     unless @edit[:new][:ws_userid].blank?
      creds[:ipmi]    = {:userid=>@edit[:new][:ipmi_userid],   :password=>@edit[:new][:ipmi_password]}   unless @edit[:new][:ipmi_userid].blank?
      @miq_proxy.host.update_authentication(creds, {:save=>false})
      @in_a_form = true
      begin
        @miq_proxy.host.verify_credentials(params[:type])
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(I18n.t("flash.credentials.validated"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    else  # Reset or first time in, set up vars for the view
      if @miq_proxy.host.available_builds.length < 1
        flash = I18n.t("flash.smartproxy.no_smartproxy_available", :name=>@miq_proxy.host.name)
        redirect_to :action => @lastaction, :id=>@miq_proxy.id, :display=>"main", :flash_msg=>flash
      end
      @edit = Hash.new
      @edit[:current_build] = @miq_proxy.build_number
      @edit[:miq_proxy_id] = @miq_proxy.id
      @edit[:proxy_choices] = Array.new
      @miq_proxy.host.available_builds.each do |pu|
        @edit[:proxy_choices].push([pu.version.split(".").last == pu.build ? pu.version : pu.version + "." + pu.build.to_s + " (#{pu.arch})", pu.id])
      end

      @edit[:new] = Hash.new
      @edit[:current] = Hash.new
      @edit[:install_build] = "<choose>"

      host = @miq_proxy.host
      @edit[:new][:default_userid] = host.authentication_userid.to_s
      @edit[:new][:default_password] = host.authentication_password.to_s
      @edit[:new][:default_verify] = host.authentication_password.to_s

      @edit[:new][:remote_userid] = host.has_authentication_type?(:remote) ? host.authentication_userid(:remote).to_s : ""
      @edit[:new][:remote_password] = host.has_authentication_type?(:remote) ? host.authentication_password(:remote).to_s : ""
      @edit[:new][:remote_verify] = host.has_authentication_type?(:remote) ? host.authentication_password(:remote).to_s : ""

      @edit[:new][:ws_userid] = host.has_authentication_type?(:ws) ? host.authentication_userid(:ws).to_s : ""
      @edit[:new][:ws_password] = host.has_authentication_type?(:ws) ? host.authentication_password(:ws).to_s : ""
      @edit[:new][:ws_verify] = host.has_authentication_type?(:ws) ? host.authentication_password(:ws).to_s : ""

      @edit[:new][:ipmi_userid]       = host.has_authentication_type?(:ipmi) ? host.authentication_userid(:ipmi).to_s : ""
      @edit[:new][:ipmi_password]     = host.has_authentication_type?(:ipmi) ? host.authentication_password(:ipmi).to_s : ""
      @edit[:new][:ipmi_verify]       = host.has_authentication_type?(:ipmi) ? host.authentication_password(:ipmi).to_s : ""

      @edit[:current] = @edit[:new].dup
      session[:changed] = false

      # Clear saved verify status flags
      session[:host_default_verify_status]  = nil
      session[:host_remote_verify_status]   = nil
      session[:host_ws_verify_status]       = nil
      session[:host_ipmi_verify_status]     = nil
      set_verify_status

      @in_a_form = true
      drop_breadcrumb( {:name=>"Deploy SmartProxy version to Host '#{@miq_proxy.host.name}'", :url=>"/miq_proxy/install_007/#{@miq_proxy.id}"} )
    end
  end

  # AJAX driven routine to check for changes in the credentials on the form
  def credential_field_changed
    @edit = session[:edit]
    @miq_proxy = session[:miq_proxy]

    @edit[:install_build] = params[:install_build] if params[:install_build]

    @edit[:new][:default_userid]          = params[:default_userid]   if params[:default_userid]
    @edit[:new][:default_password]        = params[:default_password] if params[:default_password]
    @edit[:new][:default_verify]          = params[:default_verify]   if params[:default_verify]

    @edit[:new][:remote_userid]   = params[:remote_userid]    if params[:remote_userid]
    @edit[:new][:remote_password] = params[:remote_password]  if params[:remote_password]
    @edit[:new][:remote_verify]   = params[:remote_verify]    if params[:remote_verify]

    @edit[:new][:ws_userid]       = params[:ws_userid]        if params[:ws_userid]
    @edit[:new][:ws_password]     = params[:ws_password]      if params[:ws_password]
    @edit[:new][:ws_verify]       = params[:ws_verify]        if params[:ws_verify]

    @edit[:new][:ipmi_userid]     = params[:ipmi_userid]      if params[:ipmi_userid]
    @edit[:new][:ipmi_password]   = params[:ipmi_password]    if params[:ipmi_password]
    @edit[:new][:ipmi_verify]     = params[:ipmi_verify]      if params[:ipmi_verify]

    set_verify_status
    changed = (@edit[:install_build] != "<choose>")

    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
      if @edit[:default_verify_status] != session[:host_default_verify_status]
        session[:host_default_verify_status] = @edit[:default_verify_status]
        if @edit[:default_verify_status]
          page << "miqValidateButtons('show', 'default_');"
        else
          page << "miqValidateButtons('hide', 'default_');"
        end
      end
      if @edit[:remote_verify_status] != session[:host_remote_verify_status]
        session[:host_remote_verify_status] = @edit[:remote_verify_status]
        if @edit[:remote_verify_status]
          page << "miqValidateButtons('show', 'remote_');"
        else
          page << "miqValidateButtons('hide', 'remote_');"
        end
      end
      if @edit[:ws_verify_status] != session[:host_ws_verify_status]
        session[:host_ws_verify_status] = @edit[:ws_verify_status]
        if @edit[:ws_verify_status]
          page << "miqValidateButtons('show', 'ws_');"
        else
          page << "miqValidateButtons('hide', 'ws_');"
        end
      end
      if @edit[:ipmi_verify_status] != session[:host_ipmi_verify_status]
        session[:host_ipmi_verify_status] = @edit[:ipmi_verify_status]
        if @edit[:ipmi_verify_status]
          page << "miqValidateButtons('show', 'ipmi_');"
        else
          page << "miqValidateButtons('hide', 'ipmi_');"
        end
      end
    end

  end

  def log_viewer
    identify_miq_proxy
    drop_breadcrumb( {:name=>"#{@miq_proxy.name} SmartProxy Log (last 1000 lines)", :url=>"/miq_proxy/log_viewer/#{@miq_proxy.id}"} )
    @proxy_log = @miq_proxy.log_contents(100, 1000)
    if @proxy_log == nil || @proxy_log == ""
      add_flash(I18n.t("flash.smartproxy.log_unavailable"), :warning)
      drop_breadcrumb( {:name=>"#{@miq_proxy.name} SmartProxy Log", :url=>"/miq_proxy/log_viewer/#{@miq_proxy.id}"} )
    else
      drop_breadcrumb( {:name=>"#{@miq_proxy.name} SmartProxy Log (last 1000 lines)", :url=>"/miq_proxy/log_viewer/#{@miq_proxy.id}"} )
    end
    render :action=>"show"
  end

  def get_log
    identify_miq_proxy
    drop_breadcrumb( {:name=>"#{@miq_proxy.name} SmartProxy Log (last 1000 lines)", :url=>"/miq_proxy/log_viewer/#{@miq_proxy.id}"} )
    begin
      @miq_proxy.get_agent_logs
    rescue StandardError=>bang
      add_flash(I18n.t("flash.smartproxy.retrieve_log_error") << bang.message, :error)
    else
      add_flash(I18n.t("flash.smartproxy.retrieve_log_started", :name=>@miq_proxy.name))
    end
    @proxy_log = @miq_proxy.log_contents(100)
    render :update do |page|                    # Use RJS to update the display
      page.replace(:log_div, :partial=>"log_viewer")
    end
  end

  # Send the zipped up log files
  def fetch_zip
    identify_miq_proxy
    disable_client_cache
    send_file(@miq_proxy.zip_logs(session[:userid]),
      :filename => "#{@miq_proxy.name}_SmartProxy_log.zip" )
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

      :states       => ["tasks_1","tasks_3"].include?(@tabform) ? SP_STATES : UI_STATES,
      :state_choice => "all",

      :time_period  => 0,
    }

    @tasks_options[@tabform][:zone]        = "<all>" if ["tasks_1","tasks_3"].include?(@tabform)
    @tasks_options[@tabform][:user_choice] = "all"   if ["tasks_3","tasks_4"].include?(@tabform)
  end

  # Create a condition from the passed in options
  def tasks_condition(opts, use_times = true)
    cond = [Array.new]

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
    return cond.flatten
  end

    def add_to_condition(cond, query, values)
      cond[0] << query unless query.nil?
      cond << values unless values.nil?
      cond
    end

    def build_query_for_userid(opts)
      return ["userid=?", session[:userid]] if ["tasks_1","tasks_2"].include?(@tabform)
      return ["userid=?", opts[:user_choice]] if opts[:user_choice] && opts[:user_choice] != "all"
      return nil,nil
    end

    def build_query_for_status(opts)
      cond = [Array.new]

      [:queued, :ok, :error, :warn, :running].each do |st|
        cond = add_to_condition(cond, *send("build_query_for_" + st.to_s)) if opts[st]
      end

      cond[0] = "(#{cond[0].join(" OR ")})"
      return cond
    end

    def build_query_for_queued
      ["(state=? OR state=?)", ["waiting_to_start", "Queued"]]
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
      return ["(state=? AND status=?)", ["Finished", status.capitalize]]
    end

    def build_query_for_running
      return ["(state!=? AND state!=? AND state!=?)", ["finished", "waiting_to_start", "queued"]] if vm_analysis_task?
      return ["(state!=? AND state!=? AND state!=?)", ["Finished", "waiting_to_start", "Queued"]]
    end

    def build_query_for_status_none_selected
      return ["(status!=? AND status!=? AND status!=? AND state!=? AND state!=?)",
              ["ok", "error", "warn", "finished", "waiting_to_start"]] if vm_analysis_task?
      return ["(status!=? AND status!=? AND status!=? AND state!=? AND state!=?)",
              ["Ok", "Error", "Warn", "Finished", "Queued"]]
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
      ["tasks_1","tasks_3"].include?(@tabform)
    end

  def set_verify_status
    if @edit[:new][:default_userid].blank?
      @edit[:default_verify_status] = false
    else
      @edit[:default_verify_status] = (@edit[:new][:default_password] == @edit[:new][:default_verify])
    end

    if @edit[:new][:remote_userid].blank?
      @edit[:remote_verify_status] = false
    else
      @edit[:remote_verify_status] = (@edit[:new][:remote_password] == @edit[:new][:remote_verify])
    end

    if @edit[:new][:ws_userid].blank?
      @edit[:ws_verify_status] = false
    else
      @edit[:ws_verify_status] = (@edit[:new][:ws_password] == @edit[:new][:ws_verify])
    end

    if @edit[:new][:ipmi_userid].blank?
      @edit[:ipmi_verify_status] = false
    else
      @edit[:ipmi_verify_status] = (@edit[:new][:ipmi_password] == @edit[:new][:ipmi_verify])
    end
  end

  # Validate the host record fields
  def valid_credentials?
    valid = true
    @edit[:errors] = Array.new
    if @edit[:new][:default_userid].blank?
      @edit[:errors].push("Default User ID must be entered")
      valid = false
      @tabnum = "1"
    end
    if @edit[:new][:default_userid] && @edit[:new][:default_password] != @edit[:new][:default_verify]
      @edit[:errors].push("Default Password and Verify Password fields do not match")
      valid = false
      @tabnum = "1"
    end
    if !@edit[:new][:remote_userid].blank? && @edit[:new][:remote_password] != @edit[:new][:remote_verify]
      @edit[:errors].push("Remote Login Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "2"
    end
    if !@edit[:new][:ws_userid].blank? && @edit[:new][:ws_password] != @edit[:new][:ws_verify]
      @edit[:errors].push("Web Services Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "3"
    end
    if !@edit[:new][:ipmi_userid].blank? && @edit[:new][:ipmi_password] != @edit[:new][:ipmi_verify]
      @edit[:errors].push("IPMI Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "4"
    end
    return valid
  end

  # Set credentials on the host
  def set_host_credentials(host)
    creds = Hash.new
    creds[:default] = {:userid=>@edit[:new][:default_userid],        :password=>@edit[:new][:default_password]}        unless @edit[:new][:default_userid].blank?
    creds[:remote]  = {:userid=>@edit[:new][:remote_userid], :password=>@edit[:new][:remote_password]} unless @edit[:new][:remote_userid].blank?
    creds[:ws]      = {:userid=>@edit[:new][:ws_userid],     :password=>@edit[:new][:ws_password]}     unless @edit[:new][:ws_userid].blank?
    creds[:ipmi]    = {:userid=>@edit[:new][:ipmi_userid],   :password=>@edit[:new][:ipmi_password]}   unless @edit[:new][:ipmi_userid].blank?
    host.update_authentication(creds, {:save=>true})

    AuditEvent.success(build_saved_audit(host, @edit))
  end

  def reloadjobs
    assert_privileges("miq_task_reload")
    jobs
    @refresh_partial = "layouts/tasks"
  end

  # edit single selected Object
  def deploy_build
    assert_privileges("miq_task_deploy")
    sps = find_checked_items
    sp = MiqProxy.find(sps[0])
    if sps.length > 1
      add_flash(I18n.t("flash.smartproxy.only_1_selected_for_deployment"), :error)
    elsif !sp.host.state.blank? && sp.host.state != "on"
      add_flash(I18n.t("flash.smartproxy.host_not_powered_on"), :error)
    elsif sp.host.available_builds.length == 0
      add_flash(I18n.t("flash.smartproxy.host_os_unknown"), :error)
    end
    if flash_errors?
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    end
    render :update do |page|
      page.redirect_to :action=>"install_007", :id=>sps[0]
    end
  end

  # Find the record that was chosen
  def identify_miq_proxy
    return @miq_proxy = @record = identify_record(params[:id])
  end

  # Set form variables for edit
  def set_form_vars
    @edit = Hash.new
    @edit[:miq_proxy_id] = @miq_proxy.id
    @edit[:key] = "proxy_edit__#{@miq_proxy.id || "new"}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @edit[:new][:hb_freq] = @miq_proxy.heartbeat_frequency
    @edit[:new][:hb_freq_mins] = @edit[:new][:hb_freq]/60
    @edit[:new][:hb_freq_secs] = @edit[:new][:hb_freq]%60
#   @edit[:new][:scan_freq] = @miq_proxy.scan_frequency
    @edit[:new][:update_freq] = @miq_proxy.update_frequency
    @edit[:new][:update_freq_days] = @edit[:new][:update_freq]/24/3600
    @edit[:new][:update_freq_hours] = @edit[:new][:update_freq]%(24*3600)/3600
    @edit[:new][:readonly] = @miq_proxy.read_only
    @edit[:new][:log_level] = @miq_proxy.logLevel.downcase
    @edit[:new][:log_wrapsize] = (@miq_proxy.logWrapSize.to_i / 1024 / 1024).to_s
    @edit[:new][:log_wraptime] = @miq_proxy.logWrapTime
    @edit[:new][:log_wraptime_days] = @edit[:new][:log_wraptime]/24/3600
    @edit[:new][:log_wraptime_hours] = @edit[:new][:log_wraptime]%(24*3600)/3600
    @edit[:new][:ws_port] = @miq_proxy.wsListenPort
#    @edit[:new][:forceFleeceDefault] = @miq_proxy.forceVmScan
#    @edit[:new][:vmstate_refresh_frequency] = @miq_proxy.vmstate_refresh_frequency
    @edit[:new][:name] = @miq_proxy.name

    # Get the hosts that have no miq_proxy yet for the Host pulldown list
    if ["new","create"].include?(request.parameters[:action])
      @edit[:avail_hosts] = Hash.new
      Host.all.delete_if{|h| !h.miq_proxy.blank? || !h.supports_miqproxy?}.sort{|a,b| a.name.downcase<=>b.name.downcase}.each do |host|
        @edit[:avail_hosts][host.id.to_s] = host.name
      end
    end

    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  # Get variables from edit form
  def get_form_vars
    @miq_proxy = MiqProxy.find_by_id(@edit[:miq_proxy_id])

    @edit[:new][:ws_port] = params[:ws_port] if params[:ws_port]
    @edit[:new][:readonly] = params[:readonly] == "1" ? true : false if params[:readonly]
    @edit[:new][:hb_freq_mins] = params[:hb_freq_mins] if params[:hb_freq_mins]
    @edit[:new][:hb_freq_secs] = params[:hb_freq_secs] if params[:hb_freq_secs]
    @edit[:new][:hb_freq] = @edit[:new][:hb_freq_mins].to_i * 60 + @edit[:new][:hb_freq_secs].to_i if params[:hb_freq_mins] || params[:hb_freq_days]
#     @edit[:new][:scan_freq] = params[:scan_freq][:days] .to_i * 3600 * 24 + params[:scan_freq][:hours].to_i * 3600 if params[:scan_freq]
    @edit[:new][:update_freq_days] = params[:update_freq_days] if params[:update_freq_days]
    @edit[:new][:update_freq_hours] = params[:update_freq_hours] if params[:update_freq_hours]
    @edit[:new][:update_freq] = @edit[:new][:update_freq_days].to_i * 3600 * 24 + @edit[:new][:update_freq_hours].to_i * 3600 if params[:update_freq_days] || params[:update_freq_hours]
    @edit[:new][:log_level] = params[:log_level] if params[:log_level]
    @edit[:new][:log_wrapsize] = params[:log_wrapsize] if params[:log_wrapsize]
    @edit[:new][:log_wraptime_days] = params[:log_wraptime_days] if params[:log_wraptime_days]
    @edit[:new][:log_wraptime_hours] = params[:log_wraptime_hours] if params[:log_wraptime_hours]
    @edit[:new][:log_wraptime] = @edit[:new][:log_wraptime_days].to_i * 3600 * 24 + @edit[:new][:log_wraptime_hours].to_i * 3600 if params[:log_wraptime_days] || params[:log_wraptime_hours]
#     @edit[:new][:forceFleeceDefault] = params[:forceFleeceDefault] ? true : false
#     @edit[:new][:vmstate_refresh_frequency] = params[:vmstate_refresh_frequency][:mins] .to_i * 60 + params[:vmstate_refresh_frequency][:secs].to_i if params[:vmstate_refresh_frequency]
    if params[:host]
      @edit[:new][:name] = @edit[:avail_hosts][params[:host]]                 # Pull host name from the avail_hosts hash
    elsif params[:host] && params[:host] == "<Choose>"
      @edit[:new][:name] = nil                                                # Clear the host if choose is selected
    end
    @edit[:host] = params[:host]

  end

  # Check if the miq_proxy settings have changed
  def agent_settings_changed?
    changed = false
    changed = true unless @edit[:new][:ws_port] == @edit[:current][:ws_port]
    changed = true unless @edit[:new][:hb_freq] == @edit[:current][:hb_freq]
#   changed = true unless @edit[:new][:scan_freq] == @edit[:current][:scan_freq]
    changed = true unless @edit[:new][:update_freq] == @edit[:current][:update_freq]
    changed = true unless @edit[:new][:readonly] == @edit[:current][:readonly]
    changed = true unless @edit[:new][:log_level] == @edit[:current][:log_level]
    changed = true unless @edit[:new][:log_wrapsize] == @edit[:current][:log_wrapsize]
    changed = true unless @edit[:new][:log_wraptime] == @edit[:current][:log_wraptime]
#   changed = true unless @edit[:new][:vmstate_refresh_frequency] == @edit[:current][:vmstate_refresh_frequency]
#   changed = true unless @edit[:new][:forceFleeceDefault] == @edit[:current][:forceFleeceDefault]
    return changed
  end

  # Validate the miq_proxy record fields
  def valid_record?(rec)
    valid = true
    @edit[:errors] = Array.new
    if params[:ws_port] &&  !(params[:ws_port] =~ /^\d+$/)
      @edit[:errors].push("Web Services Listen Port must be numeric")
      valid = false
    end
    if params[:log_wrapsize] && (!(params[:log_wrapsize] =~ /^\d+$/) || params[:log_wrapsize].to_i == 0)
      @edit[:errors].push("Log Wrap Size must be numeric and greater than zero")
      valid = false
    end
    return valid
  end

  # Set record variables to new values
  def set_record_vars(rec)
    rec.name = @edit[:new][:name]
#   rec.autoscan = @edit[:new][:autoscan]
#   rec.inherit_mgt_tags = @edit[:new][:inherit_mt]
#   rec.autosmart = @edit[:new][:autosmart]
    rec.heartbeat_frequency = @edit[:new][:hb_freq]
#   rec.scan_frequency = @edit[:new][:scan_freq]
    rec.update_frequency = @edit[:new][:update_freq]
    rec.read_only = @edit[:new][:readonly]
    rec.logLevel = @edit[:new][:log_level]
    rec.logWrapSize = @edit[:new][:log_wrapsize].to_i * 1024 * 1024
    rec.logWrapTime = @edit[:new][:log_wraptime]
    rec.wsListenPort = @edit[:new][:ws_port]
#    rec.forceVmScan = @edit[:new][:forceFleeceDefault]
#    rec.vmstate_refresh_frequency = @edit[:new][:vmstate_refresh_frequency]
  end

  def get_session_data
    @title         = "Smart Proxy"
    @layout        = ["my_tasks","my_ui_tasks","all_tasks","all_ui_tasks"].include?(session[:layout]) ? session[:layout] : "miq_proxy"
    @lastaction    = session[:miqproxy_lastaction]
    @display       = session[:miqproxy_display]
    @filters       = session[:miqproxy_filters]
    @catinfo       = session[:miqproxy_catinfo]
    @jobs_tab      = session[:jobs_tab] if session[:jobs_tab]
    @tabform       = session[:tabform]  if session[:tabform]
    @lastaction    = session[:jobs_lastaction]
    @tasks_options = session[:tasks_options] == nil ? "" : session[:tasks_options]
  end

  def set_session_data
    session[:miqproxy_lastaction] = @lastaction
    session[:miqproxy_display]    = @display unless @display.nil?
    session[:miqproxy_filters]    = @filters
    session[:miqproxy_catinfo]    = @catinfo
    session[:jobs_tab]            = @jobs_tab
    session[:tabform]             = @tabform
    session[:layout]              = @layout
    session[:jobs_lastaction]     = @lastaction
    session[:tasks_options]       = @tasks_options unless @tasks_options.nil?
  end

end
