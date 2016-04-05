class RepositoryController < ApplicationController
  include AuthorizationMessagesMixin
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @repo = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@repo)

    drop_breadcrumb({:name => _("Repositories"), :url => "/repository/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "miq_templates", "vms"
      title, kls = (@display == "vms" ? ["VMs", Vm] : ["Templates", MiqTemplate])
      drop_breadcrumb(:name => _("%{name}  (All %{title})") % {:name => @repo.name, :title => title},
                      :url  => "/repository/show/#{@repo.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @repo) # Get the records (into a view) and the paginator
      @showtype = @display
      @gtl_url = "/show"
      notify_about_unauthorized_items(title, _('Repository'))

    when "download_pdf", "main", "summary_only"
      get_tagdata(@repo)
      session[:vm_summary_cool] = (@settings[:views][:vm_summary_cool] == "summary")
      @summary_view = session[:vm_summary_cool]
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @repo.name},
                      :url  => "/repository/show/#{@repo.id}?display=main")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)
    end
    @lastaction = "show"

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
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
    @in_a_form = true
    drop_breadcrumb(:name => _("Add New Repository"), :url => "/repository/new")
  end

  def create
    assert_privileges("repository_new")
    case params[:button]
    when "cancel"
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => _("Add of new %{model} was cancelled by the user") %
          {:model => ui_lookup(:model => "Repository")}
      end
    when "add"
      if %w(NAS VMFS).include?(params[:path_type])
        @repo = Repository.new(:name => params[:repo_name], :path => params[:repo_path])
        if @repo.save
          construct_edit
          AuditEvent.success(build_created_audit(@repo, @edit))
          render :update do |page|
            page.redirect_to :action => 'show_list', :flash_msg => _("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "Repository"), :name => @repo.name}
          end
          return
        else
          @repo.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
        end
      else
        add_flash(_("Path must be a valid reference to a UNC location"), :error)
        @repo = Repository.new
      end
      @in_a_form = true
      drop_breadcrumb(:name => _("Add New Repository"), :url => "/repository/new")
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  def repository_form_fields
    assert_privileges("repository_edit")
    repository = find_by_id_filtered(Repository, params[:id])
    render :json => {
      :repo_name => repository.name,
      :repo_path => repository.path
    }
  end

  def edit
    assert_privileges("repository_edit")
    @repo = find_by_id_filtered(Repository, params[:id])
    session[:changed] = false
    @in_a_form = true
    drop_breadcrumb(:name => _("Edit Repository '%{name}'") % {:name => @repo.name},
                    :url  => "/repository/edit/#{@repo.id}")
  end

  def update
    assert_privileges("repository_edit")
    @repo = find_by_id_filtered(Repository, params[:id])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      render :update do |page|
        page.redirect_to :action => @lastaction, :id => @repo.id, :display => session[:repo_display],
          :flash_msg => _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "Repository"), :name => @repo.name}
      end
    when "save"
      if %w(NAS VMFS).include?(params[:path_type])
        construct_edit
        if @repo.update_attributes(:name => params[:repo_name], :path => params[:repo_path])
          AuditEvent.success(build_saved_audit(@repo, @edit))
          session[:edit] = nil  # clean out the saved info
          flash = _("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "Repository"), :name => @repo.name}
          render :update do |page|
            page.redirect_to :action => 'show', :id => @repo.id.to_s, :flash_msg => flash
          end
        else
          @repo.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          drop_breadcrumb(:name => _("Edit Repository '%{name}'") % {:name => @repo.name},
                          :url  => "/repository/edit/#{@repo.id}")
          @in_a_form = true
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      else
        add_flash(_("Path must be a valid reference to a UNC location"), :error)
        drop_breadcrumb(:name => _("Edit Repository '%{name}'") % {:name => @repo.name},
                        :url  => "/repository/edit/#{@repo.id}")
        @in_a_form = true
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "reset"
      add_flash(_("All changes have been reset"), :warning)
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action => 'edit', :id => @repo.id
      end
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = "vms" if @display == "vms"   # Were we displaying vms

    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      return if ["#{pfx}_compare", "#{pfx}_tag", "#{pfx}_policy_sim", "#{pfx}_protect", "#{pfx}_right_size",
                 "#{pfx}_retire", "#{pfx}_ownership", "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array.nil? # Compare or tag screen is showing, so return

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    else                                        # Handle Repo buttons
      params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      redirect_to :action => "new" if params[:pressed] == "new"
      deleterepos if params[:pressed] == "repository_delete"
      #     scanrepos if params[:pressed] == "scan"
      refreshrepos if params[:pressed] == "refresh"
      refreshrepos if params[:pressed] == "repository_refresh"
      tag(Repository) if params[:pressed] == "repository_tag"
      assign_policies(Repository) if params[:pressed] == "repository_protect"
      edit_record if params[:pressed] == "repository_edit"

      return if ["repository_tag", "repository_protect"].include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return

      unless @refresh_partial # if no button handler ran, show not implemented msg
        add_flash(_("Button not yet implemented"), :error)
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      end
    end

    if !@flash_array.nil? && params[:pressed] == "delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  private ############################

  def construct_edit
    @edit ||= {}
    @edit[:current] = {:name => @repo.name, :path => @repo.path}
    @edit[:new] = {:name => params[:repo_name], :path => params[:repo_path]}
  end

  def process_repos(repos, task)
    if task == "refresh"
      sp = nil                              # Init the smartproxy
      spid = get_vmdb_config[:repository_scanning][:defaultsmartproxy]
      if spid.nil?
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
          add_flash(_("Error during 'refresh': %{message}") % {:message => bang.message}, :error)
          return
        end
        if sp.state != "on"                     # Repo scanning SmartProxy not running
          add_flash(_("The Default Repository SmartProxy, \"%{name}\", is not running, contact your CFME Administrator") %
                      {:name => sp.name}, :error)
          return
        end
      end
    end
    if task == "destroy"
      Repository.where(:id => repos).order("lower(name)").each do |repo|
        id = repo.id
        repo_name = repo.name
        audit = {:event => "repo_record_delete_initiated", :message => _("[%{name}] Record delete initiated") %
          {:name => repo_name}, :target_id => id, :target_class => "Repository", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Repository.destroy_queue(repos)
      add_flash(_("Delete initiated for %{count_model} from the CFME Database") %
                  {:count_model => pluralize(repos.length, "Repository")})
    else
      Repository.where(:id => repos).order("lower(name)").each do |repo|
        id = repo.id
        repo_name = repo.name
        audit = if task == "destroy"
                  {:event        => "repository_record_delete",
                   :message      => _("[%{name}] Record deleted") % {:name => repo_name},
                   :target_id    => id,
                   :target_class => "Repository",
                   :userid       => session[:userid]}
                end
        begin
          if task == "refresh"
            sp.scan_repository(repo)              # Run the scan off of the configured SmartProxy
          else
            repo.send(task.to_sym) if repo.respond_to?(task)  # Run the task
          end
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{message}") %
                      {:model   => ui_lookup(:model => "Repository"), :name => repo_name, :task => task,
                       :message => bang.message}, :error)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => ui_lookup(:model => "Repository"), :name => repo_name})
          else
            add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record => repo_name, :task => task})
          end
        end
      end
    end
  end

  # Delete all selected or single displayed repo(s)
  def deleterepos
    assert_privileges("repository_delete")
    repos = []
    if @lastaction == "show_list" # showing a list, scan all selected repos
      repos = find_checked_items
      if repos.empty?
        add_flash(_("No %{model} were selected for deletion") % {:model => ui_lookup(:tables => "repository")}, :error)
      end
      process_repos(repos, "destroy") unless repos.empty?
      add_flash(_("Delete initiated for %{count_model} from the CFME Database") %
                  {:count_model => pluralize(repos.length, "Repository")}) if @flash_array.nil?
    else # showing 1 repository, scan it
      if params[:id].nil? || Repository.find_by_id(params[:id]).nil?
        add_flash(_("Repository no longer exists"), :error)
      else
        repos.push(params[:id])
      end
      @single_delete = true
      process_repos(repos, "destroy") unless repos.empty?
      add_flash(_("The selected Repository was deleted")) if @flash_array.nil?
    end
    show_list
    @refresh_partial = "layouts/gtl"
  end

  # Refresh all selected or single displayed repo(s)
  def refreshrepos
    assert_privileges("repository_refresh")
    repos = []
    if @lastaction == "show_list" # showing a list, scan all selected repositories
      repos = find_checked_items
      if repos.empty?
        add_flash(_("No %{model} were selected for refresh") % {:model => ui_lookup(:tables => "repository")}, :error)
      end
      process_repos(repos, "refresh") unless repos.empty?
      add_flash(_("Refresh initiated for %{count_model} from the CFME Database") %
                  {:count_model => pluralize(repos.length, ui_lookup(:table => "Repository"))}) if @flash_array.nil?
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 repo, refresh it
      if params[:id].nil? || Repository.find_by_id(params[:id]).nil?
        add_flash(_("Repository no longer exists"), :error)
      else
        repos.push(params[:id])
      end
      process_repos(repos, "refresh") unless repos.empty?
      add_flash(_("Refresh initiated for %{count_model} from the CFME Database") %
                  {:count_model => pluralize(repos.length, ui_lookup(:table => "Repository"))}) if @flash_array.nil?
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
    page = params[:page].nil? ? 1 : params[:page].to_i
    @current_page = page
    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @repo_pages, @repos = paginate(:repositories, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

  def get_session_data
    @title      = _("Repositories")
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
