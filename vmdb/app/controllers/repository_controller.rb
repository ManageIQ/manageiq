class RepositoryController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @repo = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@repo)

    drop_breadcrumb({:name=>"Repositories", :url=>"/repository/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "miq_templates", "vms"
      title, kls = (@display == "vms" ? ["VMs", Vm] : ["Templates", MiqTemplate])
      drop_breadcrumb( {:name=>@repo.name+" (All #{title})", :url=>"/repository/show/#{@repo.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent=>@repo) # Get the records (into a view) and the paginator
      @showtype = @display
      @gtl_url = "/repository/show/" << @repo.id.to_s << "?"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this Repository"
      end

    when "download_pdf", "main", "summary_only"
      get_tagdata(@repo)
      session[:vm_summary_cool] = (@settings[:views][:vm_summary_cool] == "summary")
      @summary_view = session[:vm_summary_cool]
      drop_breadcrumb( {:name=>@repo.name + " (Summary)", :url=>"/repository/show/#{@repo.id}?display=main"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    end
    @lastaction = "show"

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main Repository list view
  def show_list
    process_show_list
  end

  def new
    assert_privileges("repository_new")
    @repo = Repository.new
    set_form_vars
    @in_a_form = true
    drop_breadcrumb( {:name=>"Add New Repository", :url=>"/repository/new"} )
  end

  def create
    assert_privileges("repository_new")
    return unless load_edit("repo_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      render :update do |page|
        page.redirect_to :action=>'show_list', :flash_msg=>_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"Repository")
      end
    when "add"
      valid, type = Repository.valid_path?(@edit[:new][:path])
      if valid && ["NAS","VMFS"].include?(type)
        @repo = Repository.new(@edit[:new])
        if @repo.save
          AuditEvent.success(build_created_audit(@repo, @edit))
          render :update do |page|
            page.redirect_to :action=>'show_list', :flash_msg=>_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"Repository"), :name=>@repo.name}
          end
          return
        else
          @repo.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
        end
      else
        add_flash(_("Path must be a valid reference to a UNC location"), :error)
        @repo = Repository.new
      end
      @in_a_form = true
      drop_breadcrumb( {:name=>"Add New Repository", :url=>"/repository/new"} )
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def edit
    assert_privileges("repository_edit")
    @repo = find_by_id_filtered(Repository, params[:id])
    set_form_vars
    session[:changed] = false
    @in_a_form = true
    drop_breadcrumb( {:name=>"Edit Repository '#{@repo.name}'", :url=>"/repository/edit/#{@repo.id}"} )
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("repo_edit__#{params[:id]}")
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
    assert_privileges("repository_edit")
    return unless load_edit("repo_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    @repo = find_by_id_filtered(Repository, params[:id])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      render :update do |page|
        page.redirect_to :action=>@lastaction, :id=>@repo.id, :display=>session[:repo_display],
          :flash_msg=>_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"Repository"), :name=>@repo.name}
      end
    when "save"
      valid, type = Repository.valid_path?(@edit[:new][:path])
      if valid && ["NAS","VMFS"].include?(type)
        if @repo.update_attributes(@edit[:new][:repo])
          AuditEvent.success(build_saved_audit(@repo, @edit))
          session[:edit] = nil  # clean out the saved info
          flash = _("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"Repository"), :name=>@repo.name}
          render :update do |page|
          page.redirect_to :action=>'show', :id=>@repo.id.to_s, :flash_msg=>flash
        end
        else
        session[:changed] = changed
        @changed = true
          @repo.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          drop_breadcrumb( {:name=>"Edit Repository '#{@repo.name}'", :url=>"/repository/edit/#{@repo.id}"} )
          @in_a_form = true
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        end
      else
        session[:changed] = changed
        @changed = true
        add_flash(_("Path must be a valid reference to a UNC location"), :error)
        drop_breadcrumb( {:name=>"Edit Repository '#{@repo.name}'", :url=>"/repository/edit/#{@repo.id}"} )
        @in_a_form = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "reset"
      add_flash(_("All changes have been reset"), :warning)
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'edit', :id=>@repo.id
      end
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = "vms" if @display == "vms"   # Were we displaying vms

    if params[:pressed].starts_with?("vm_") ||      # Handle buttons from sub-items screen
        params[:pressed].starts_with?("miq_template_") ||
        params[:pressed].starts_with?("guest_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      return if ["#{pfx}_compare", "#{pfx}_tag", "#{pfx}_policy_sim","#{pfx}_protect","#{pfx}_right_size",
                  "#{pfx}_retire","#{pfx}_ownership","#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array == nil # Compare or tag screen is showing, so return

      if !["#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    else                                        # Handle Repo buttons
      params[:page] = @current_page if @current_page != nil # Save current page for list refresh
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      redirect_to :action=>"new" if params[:pressed] == "new"
      deleterepos if params[:pressed] == "repository_delete"
#     scanrepos if params[:pressed] == "scan"
      refreshrepos if params[:pressed] == "refresh"
      refreshrepos if params[:pressed] == "repository_refresh"
      tag(Repository) if params[:pressed] == "repository_tag"
      assign_policies(Repository) if params[:pressed] == "repository_protect"
      edit_record if params[:pressed] == "repository_edit"

      return if ["repository_tag","repository_protect"].include?(params[:pressed]) &&
                @flash_array == nil # Tag screen showing, so return

      if ! @refresh_partial # if no button handler ran, show not implemented msg
        add_flash(_("Button not yet implemented"), :error)
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      end
    end

    if !@flash_array.nil? && params[:pressed] == "delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new","#{pfx}_clone",
                                                   "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
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
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|                    # Use RJS to update the display
          if @refresh_partial != nil
            if @refresh_div == "flash_msg_div"
              page.replace(@refresh_div, :partial=>@refresh_partial)
            else
              if @display == "vms"  # If displaying vms, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@repo.id}"})
              else
                page.replace_html(@refresh_div, :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end

  end

  private ############################

  # Set form variables for edit
  def set_form_vars
    @edit = Hash.new
    @edit[:repo_id] = @repo.id
    @edit[:key] = "repo_edit__#{@repo.id || "new"}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new][:name] = @repo.name
    @edit[:new][:path] = @repo.path
    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  # Get variables from edit form
  def get_form_vars
    @edit[:new][:name] = params[:repo_name] if params[:repo_name]
    @edit[:new][:path] = params[:repo_path] if params[:repo_path]
    @repo = @edit[:repo_id] ? @edit[:repo_id] : Repository.new
  end

  def process_repos(repos, task)
    if task == "refresh"
      current = VMDB::Config.new("vmdb")    # Get the vmdb configuration settings
      sp = nil                              # Init the smartproxy
      spid = current.config[:repository_scanning][:defaultsmartproxy]
      if spid == nil
        add_flash(_("No Default Repository SmartProxy is configured, contact your CFME Administrator"), :error)
        return
      elsif MiqProxy.exists?(spid) == false
        add_flash(_("The Default Repository SmartProxy no longer exists, contact your CFME Administrator"), :error)
        return
      else
        begin
          sp = MiqProxy.find(spid)
        rescue StandardError => bang
          add_flash(_("The Default Repository SmartProxy is not valid, contact your CFME Administrator"), :error)
          add_flash(_("Error during '%s': ") % "refresh" << bang.message, :error)
          return
        end
        if sp.state != "on"                     # Repo scanning SmartProxy not running
          add_flash(_("The Default Repository SmartProxy, \"%s\", is not running, contact your CFME Administrator") % sp.name, :error)
          return
        end
      end
    end
    if task == "destroy"
      Repository.find_all_by_id(repos, :order => "lower(name)").each do |repo|
        id = repo.id
        repo_name = repo.name
        audit = {:event=>"repo_record_delete_initiated", :message=>"[#{repo_name}] Record delete initiated", :target_id=>id, :target_class=>"Repository", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Repository.destroy_queue(repos)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(repos.length,"Repository")})
    else
      Repository.find_all_by_id(repos, :order => "lower(name)").each do |repo|
        id = repo.id
        repo_name = repo.name
        audit = {:event=>"repository_record_delete", :message=>"[#{repo_name}] Record deleted", :target_id=>id, :target_class=>"Repository", :userid => session[:userid]} if task == "destroy"
        begin
          if task == "refresh"
            sp.scan_repository(repo)              # Run the scan off of the configured SmartProxy
          else
            repo.send(task.to_sym) if repo.respond_to?(task)  # Run the task
          end
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"Repository"), :name=>repo_name, :task=>task} << bang.message, :error)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>ui_lookup(:model=>"Repository"), :name=>repo_name})
          else
            add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record=>repo_name, :task=>task})
          end
        end
      end
    end
  end

  # Delete all selected or single displayed repo(s)
  def deleterepos
    assert_privileges("repository_delete")
    repos = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected repos
      repos = find_checked_items
      if repos.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"repository"), :task=>"deletion"}, :error)
      end
      process_repos(repos, "destroy") if ! repos.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(repos.length,"Repository")}) if @flash_array == nil
    else # showing 1 repository, scan it
      if params[:id] == nil || Repository.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % "Repository", :error)
      else
        repos.push(params[:id])
      end
      @single_delete = true
      process_repos(repos, "destroy") if ! repos.empty?
      add_flash(_("The selected %s was deleted") % "Repository") if @flash_array == nil
    end
    show_list
    @refresh_partial = "layouts/gtl"
  end

  # Refresh all selected or single displayed repo(s)
  def refreshrepos
    assert_privileges("repository_refresh")
    repos = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected repositories
      repos = find_checked_items
      if repos.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"repository"), :task=>"refresh"}, :error)
      end
      process_repos(repos, "refresh") unless repos.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Refresh", :count_model=>pluralize(repos.length,ui_lookup(:table=>"Repository"))}) if @flash_array == nil
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 repo, refresh it
      if params[:id] == nil || Repository.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % "Repository", :error)
      else
        repos.push(params[:id])
      end
      process_repos(repos, "refresh") if ! repos.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Refresh", :count_model=>pluralize(repos.length,ui_lookup(:table=>"Repository"))}) if @flash_array == nil
      params[:display] = @display
      show
      if @display == "vms"
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "main"
      end
    end
  end

  # gather up the repository records from the DB
  def get_repos
    page = params[:page] == nil ? 1 : params[:page].to_i
    @current_page = page
    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @repo_pages, @repos = paginate(:repositories, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

  def get_session_data
    @title      = "Repositories"
    @layout     = "repository"
    @lastaction = session[:repo_lastaction]
    @display    = session[:repo_display]
    @filters    = session[:repo_filters]
    @catinfo    = session[:repo_catinfo]
  end

  def set_session_data
    session[:repo_lastaction] = @lastaction
    session[:repo_display]    = @display unless @display.nil?
    session[:repo_filters]    = @filters
    session[:repo_catinfo]    = @catinfo
  end

end
