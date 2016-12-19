class HostAggregateController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::CheckedIdMixin

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    @host_aggregate = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@host_aggregate)

    @gtl_url = "/show"
    drop_breadcrumb({:name => _("Host Aggregates"),
                     :url  => "/host_aggregate/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@host_aggregate)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @host_aggregate.name},
                      :url  => "/availability_zone/show/#{@host_aggregate.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)

    when "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @host_aggregate.name},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}&refresh=n")
      perf_gen_init_options # Intialize perf chart options, charts will be generated async

    when "ems_cloud"
      drop_breadcrumb(:name => _("%{name} (%{table}(s))") % {:name  => @host_aggregate.name,
                                                             :table => ui_lookup(:table => "ems_cloud")},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=ems_cloud")
      # Get the records (into a view) and the paginator
      @view, @pages = get_view(ManageIQ::Providers::CloudManager, :parent => @host_aggregate)
      @showtype = "ems_cloud"

    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @host_aggregate.name, :title => title},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}")
      # Get the records (into a view) and the paginator
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @host_aggregate)
      @showtype = @display

    when "hosts"
      title = ui_lookup(:tables => "host")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @host_aggregate.name, :title => title},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}")
      @view, @pages = get_view(Host, :parent => @host_aggregate) # Get the records (into a view) and the paginator
      @showtype = @display

    when "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(HostAggregate, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"),
                      :url  => "/host_aggregate/show/#{@record.id}?refresh=n&display=timeline")
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def host_aggregate_form_fields
    assert_privileges("host_aggregate_edit")
    host_aggregate = find_by_id_filtered(HostAggregate, params[:id])
    render :json => {
      :name    => host_aggregate.name,
      :ems_id  => host_aggregate.ems_id
    }
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box

    params[:display] = @display if %w(images instances).include?(@display) # Were we displaying vms/hosts/storages
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    if params[:pressed].starts_with?("image_", # Handle buttons from sub-items screen
                                     "instance_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      # Control transferred to another screen, so return
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag",
                 "#{pfx}_retire", "#{pfx}_protect", "#{pfx}_ownership",
                 "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show # Handle VMs buttons
      end
    else
      tag(HostAggregate) if params[:pressed] == "host_aggregate_tag"
      return if ["host_aggregate_tag"].include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return
    end

    if params[:pressed] == "host_aggregate_new"
      javascript_redirect :action => "new"
      return
    elsif params[:pressed] == "host_aggregate_edit"
      javascript_redirect :action => "edit", :id => checked_item_id
      return
    elsif params[:pressed] == 'host_aggregate_delete'
      delete_host_aggregates
      render_flash
      return
    elsif params[:pressed] == "host_aggregate_add_host"
      javascript_redirect :action => "add_host_select", :id => checked_item_id
      return
    elsif params[:pressed] == "host_aggregate_remove_host"
      javascript_redirect :action => "remove_host_select", :id => checked_item_id
      return
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    elsif @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render :update do |page|
        page << javascript_prologue
        unless @refresh_partial.nil?
          if @refresh_div == "flash_msg_div"
            page.replace(@refresh_div, :partial => @refresh_partial)
          elsif %w(images instances).include?(@display) # If displaying vms, action_url s/b show
            page << "miqSetButtons(0, 'center_tb');"
            page.replace_html("main_div",
                              :partial => "layouts/gtl",
                              :locals  => {:action_url => "show/#{@host_aggregate.id}"})
          else
            page.replace_html(@refresh_div, :partial => @refresh_partial)
          end
        end
      end
    end

    unless @refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
  end

  def new
    assert_privileges("host_aggregate_new")
    @host_aggregate = HostAggregate.new
    @in_a_form = true
    @ems_choices = {}
    ManageIQ::Providers::CloudManager.select { |ems| ems.supports?(:create_host_aggregate) }.each do |ems|
      @ems_choices[ems.name] = ems.id
    end

    drop_breadcrumb(
      :name => _("Create New %{model}") % {:model => ui_lookup(:table => 'host_aggregate')},
      :url  => "/host_aggregate/new"
    )
  end

  def create
    assert_privileges("host_aggregate_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Creation of new %{model} was cancelled by the user") % {
                            :model => ui_lookup(:table => 'host_aggregate')
                          }

    when "add"
      @host_aggregate = HostAggregate.new
      options = form_params(params)
      ext_management_system = find_by_id_filtered(ManageIQ::Providers::CloudManager,
                                                  options[:ems_id])
      if ext_management_system.supports?(:create_host_aggregate)
        task_id = ext_management_system.create_host_aggregate_queue(session[:userid], options)

        add_flash(_("Host Aggregate creation failed: Task start failed: ID [%{id}]") %
                  {:id => task_id.to_s}, :error) unless task_id.kind_of?(Integer)

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Host Aggregates not supported by chosen provider"), :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    host_aggregate_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" created") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => host_aggregate_name
      })
    else
      add_flash(_("Unable to create %{model} \"%{name}\": %{details}") % {
        :model   => ui_lookup(:table => 'host_aggregate'),
        :name    => host_aggregate_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show_list"
  end

  def edit
    assert_privileges("host_aggregate_edit")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'host_aggregate'),
                                                 :name  => @host_aggregate.name},
      :url  => "/host_aggregate/edit/#{@host_aggregate.id}"
    )
  end

  def update
    assert_privileges("host_aggregate_edit")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => @host_aggregate.name
      })

    when "save"
      options = form_params(params)

      if @host_aggregate.supports?(:update_aggregate)
        task_id = @host_aggregate.update_aggregate_queue(session[:userid], options)

        unless task_id.kind_of?(Integer)
          add_flash(_("Edit of %{model} \"%{name}\" failed: Task start failed: ID [%{id}]") % {
            :model => ui_lookup(:table => 'host_aggregate'),
            :name  => @host_aggregate.name,
            :id    => task_id.to_s
          }, :error)
        end

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Update aggregate not supported by %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'host_aggregate'),
          :name  => @host_aggregate.name
        }, :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    host_aggregate_id = session[:async][:params][:id]
    host_aggregate_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" updated") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => host_aggregate_name
      })
    else
      add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
        :model   => ui_lookup(:table => 'host_aggregate'),
        :name    => host_aggregate_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => host_aggregate_id
  end

  def delete_host_aggregates
    assert_privileges("host_aggregate_delete")

    host_aggregates = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "host_aggregate")
                        find_checked_items
                      else
                        [params[:id]]
                      end

    if host_aggregates.empty?
      add_flash(_("No %{models} were selected for deletion.") % {
        :models => ui_lookup(:tables => "host_aggregate")
      }, :error)
    end

    host_aggregates_to_delete = []
    host_aggregates.each do |host_aggregate_id|
      host_aggregate = HostAggregate.find(host_aggregate_id)
      if host_aggregate.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "host_aggregate")}, :error)
      elsif !host_aggregate.supports?(:delete_aggregate)
        add_flash(_("Delete aggregate not supported by %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'host_aggregate'),
          :name  => host_aggregate.name
        }, :error)
      else
        host_aggregates_to_delete.push(host_aggregate)
      end
    end
    process_host_aggregates(host_aggregates_to_delete, "destroy") unless host_aggregates_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "host_aggregate"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected %{model} was deleted") % {:model => ui_lookup(:table => "host_aggregate")})
      end
    end
  end

  def add_host_select
    assert_privileges("host_aggregate_add_host")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])
    @in_a_form = true
    @host_choices = {}
    ems_clusters = @host_aggregate.ext_management_system.provider.try(:infra_ems).try(:ems_clusters)

    unless ems_clusters.blank?
      ems_clusters.select(&:compute?).each do |ems_cluster|
        (ems_cluster.hosts - @host_aggregate.hosts).each do |host|
          @host_choices["#{host.name}: #{host.hostname}"] = host.id
        end
      end
    end
    if @host_choices.empty?
      add_flash(_("No hosts available to add to %{model} \"%{name}\"") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => @host_aggregate.name
      }, :error)
      session[:flash_msgs] = @flash_array
      @in_a_form = false
      if @lastaction == "show_list"
        redirect_to(:action => "show_list")
      else
        redirect_to(:action => "show", :id => params[:id])
      end
    else
      drop_breadcrumb(
        :name => _("Add Host to %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'host_aggregate'),
                                                          :name  => @host_aggregate.name},
        :url  => "/host_aggregate/add_host/#{@host_aggregate.id}"
      )
    end
  end

  def add_host
    assert_privileges("host_aggregate_add_host")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Add Host to %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => @host_aggregate.name
      })

    when "addHost"
      options = form_params(params)
      host = find_by_id_filtered(Host, options[:host_id])

      if @host_aggregate.supports?(:add_host)
        task_id = @host_aggregate.add_host_queue(session[:userid], host)

        unless task_id.kind_of?(Integer)
          add_flash(_("Add Host to %{model} \"%{name}\" failed: Task start failed: ID [%{id}]") % {
            :model => ui_lookup(:table => 'host_aggregate'),
            :name  => @host_aggregate.name,
            :id    => task_id.to_s
          }, :error)
        end

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "add_host_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Add Host not supported by %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'host_aggregate'),
          :name  => @host_aggregate.name
        }, :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def add_host_finished
    task_id = session[:async][:params][:task_id]
    host_aggregate_id = session[:async][:params][:id]
    host_aggregate_name = session[:async][:params][:name]
    host_id = session[:async][:params][:host_id]

    task = MiqTask.find(task_id)
    host = Host.find(host_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Host \"%{hostname}\" added to %{model} \"%{name}\"") % {
        :hostname => host.name,
        :model    => ui_lookup(:table => 'host_aggregate'),
        :name     => host_aggregate_name
      })
    else
      add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
        :model   => ui_lookup(:table => 'host_aggregate'),
        :name    => host_aggregate_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => host_aggregate_id
  end

  def remove_host_select
    assert_privileges("host_aggregate_remove_host")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])
    @in_a_form = true
    @host_choices = {}
    @host_aggregate.hosts.each do |host|
      @host_choices["#{host.name}: #{host.hostname}"] = host.id
    end

    if @host_choices.empty?
      add_flash(_("No hosts to remove from %{model} \"%{name}\"") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => @host_aggregate.name
      }, :error)
      session[:flash_msgs] = @flash_array
      @in_a_form = false
      if @lastaction == "show_list"
        redirect_to(:action => "show_list")
      else
        redirect_to(:action => "show", :id => params[:id])
      end
    else
      drop_breadcrumb(
        :name => _("Remove Host from %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'host_aggregate'),
                                                               :name  => @host_aggregate.name},
        :url  => "/host_aggregate/remove_host/#{@host_aggregate.id}"
      )
    end
  end

  def remove_host
    assert_privileges("host_aggregate_remove_host")
    @host_aggregate = find_by_id_filtered(HostAggregate, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Remove Host from %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'host_aggregate'),
        :name  => @host_aggregate.name
      })

    when "removeHost"
      options = form_params(params)
      host = find_by_id_filtered(Host, options[:host_id])

      if @host_aggregate.supports?(:remove_host)
        task_id = @host_aggregate.remove_host_queue(session[:userid], host)

        unless task_id.kind_of?(Integer)
          add_flash(_("Remove Host to %{model} \"%{name}\" failed: Task start failed: ID [%{id}]") % {
            :model => ui_lookup(:table => 'host_aggregate'),
            :name  => @host_aggregate.name,
            :id    => task_id.to_s
          }, :error)
        end

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "remove_host_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Remove Host not supported by %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'host_aggregate'),
          :name  => @host_aggregate.name
        }, :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def remove_host_finished
    task_id = session[:async][:params][:task_id]
    host_aggregate_id = session[:async][:params][:id]
    host_aggregate_name = session[:async][:params][:name]
    host_id = session[:async][:params][:host_id]

    task = MiqTask.find(task_id)
    host = Host.find(host_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Host \"%{hostname}\" removed from %{model} \"%{name}\"") % {
        :hostname => host.name,
        :model    => ui_lookup(:table => 'host_aggregate'),
        :name     => host_aggregate_name
      })
    else
      add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
        :model   => ui_lookup(:table => 'host_aggregate'),
        :name    => host_aggregate_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => host_aggregate_id
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @host_aggregate.id,
                        :display   => session[:host_aggregate_display],
                        :flash_msg => message
  end

  private ############################

  def form_params(in_params)
    options = {}
    [:name, :availability_zone, :ems_id, :host_id, :metadata].each do |param|
      options[param] = in_params[param] if in_params[param]
    end
    options
  end

  # dispatches tasks to multiple host aggregates
  def process_host_aggregates(host_aggregates, task)
    return if host_aggregates.empty?

    return unless task == "destroy"

    host_aggregates.each do |host_aggregate|
      audit = {
        :event        => "host_aggregate_record_delete_initiateed",
        :message      => "[#{host_aggregate.name}] Record delete initiated",
        :target_id    => host_aggregate.id,
        :target_class => "HostAggregate",
        :userid       => session[:userid]
      }
      AuditEvent.success(audit)
      host_aggregate.delete_aggregate_queue(session[:userid])
    end
    add_flash(n_("Delete initiated for %{number} Host Aggregate.",
                 "Delete initiated for %{number} Host Aggregates.",
                 host_aggregates.length) % {:number => host_aggregates.length})
  end

  def get_session_data
    @title      = _("Host Aggregate")
    @layout     = "host_aggregate"
    @lastaction = session[:host_aggregate_lastaction]
    @display    = session[:host_aggregate_display]
    @filters    = session[:host_aggregate_filters]
    @catinfo    = session[:host_aggregate_catinfo]
  end

  def set_session_data
    session[:host_aggregate_lastaction] = @lastaction
    session[:host_aggregate_display]    = @display unless @display.nil?
    session[:host_aggregate_filters]    = @filters
    session[:host_aggregate_catinfo]    = @catinfo
  end

  menu_section :clo
end
