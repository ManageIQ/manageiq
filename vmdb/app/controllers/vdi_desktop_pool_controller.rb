class VdiDesktopPoolController < VdiBaseController

  def index
    process_index
  end

  def button
    # button pressed on users sub-list view
    case params[:pressed]
    when 'vdi_user_desktop_pool_unassign'
      user_unassign
    when 'vdi_desktop_pool_edit', 'vdi_desktop_pool_new'
      edit_record
    when 'vdi_desktop_unmark_vdi'
      unmark_vdi
      return
    # button pressed on users list/show screen
    # return, let buttons method handle everything
    when 'vdi_desktop_pool_manage_desktops'
      vdi_desktop_pool_manage_desktops
      return
    when 'vdi_desktop_pool_user_assign', 'vdi_user_desktop_pool_assign'
      user_assignment
      return
    end

    @refresh_div = 'main_div' # Default div for button.rjs to refresh

    if @flash_array && @lastaction == "show"
      @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
    if !@flash_array.nil? && params[:pressed] == "vdi_desktop_pool_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to show_list
      end
    elsif params[:pressed].ends_with?("_edit") || params[:pressed].ends_with?("_new")
      if @redirect_controller
        if @redirect_id
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial
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
              page.replace_html(@refresh_div, :partial=>@refresh_partial)
            end
          end
        end
      end
    end
  end

  def show
    process_show(
      'ext_management_system' => :ext_management_systems,
      'vdi_desktop' => :vdi_desktops,
      'vdi_user'    => :vdi_users,
      'unassigned_vdi_desktop' => :unassigned_vdi_desktops
    )
  end

  def show_list
    process_show_list
  end

  def new
    assert_privileges("vdi_desktop_pool_new")
    @record = VdiDesktopPool.new
    set_form_vars
    @in_a_form        = true
    session[:changed] = nil
    drop_breadcrumb( {:name =>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
  end

  def edit
    assert_privileges("vdi_desktop_pool_edit")
    @record = find_by_id_filtered(VdiDesktopPool, params[:id])
    set_form_vars
    @in_a_form        = true
    session[:changed] = false
    drop_breadcrumb( {:name=>"Edit #{ui_lookup( :table => self.class.table_name )} '#{@record.name}'", :url=>"/#{self.class.table_name}/edit/#{@record.id}"} )
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("vdp_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])

    render :update do |page|                    # Use JS to update the display
      page.replace("form_div", :partial=>"form") if params[:vdi_farm_id]
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def create
    create_update
  end

  def update
    create_update
  end

  def manage_desktops
    case params[:button]
      when "cancel"
        @in_a_form = false
        session[:edit] = @edit = nil  # clean out the saved info
        flash = I18n.t("flash.edit.manage_desktops_cancelled")
        redirect_to :action=>"show", :id=>params[:id], :flash_msg=>flash, :escape=>false
      when "save"
        return unless load_edit("dp_edit__#{params[:id]}")
        manage_desktops_get_form_vars
        @dp = VdiDesktopPool.find_by_id(from_cid(@edit[:rec_id]))
        manage_desktops_set_record_vars
        if @dp.save
          flash = I18n.t("flash.edit.manage_desktops_saved")
          @changed = session[:changed] = false
          @in_a_form = false
          @edit = session[:edit] = nil
          redirect_to :action=>"show", :id=>params[:id], :flash_msg=>flash, :escape=>false
        end
      when "reset",nil
        add_flash(I18n.t("flash.edit.reset"), :warning) if params[:button] == "reset"
        @manage_desktops = true
        manage_desktops_set_form_vars
        @in_a_form = true
        @changed = session[:changed] = false
        render :action=>"show"
    end
  end

  def manage_desktops_form_field_changed
    return unless load_edit("dp_edit__#{params[:id]}")
    manage_desktops_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(@changed)
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg") if @flash_array
      page.replace("form", :partial=>"manage_desktops") if !@flash_array
      page << "miqSparkle(false);"
    end
  end

  def vdi_desktop_pool_manage_desktops
    assert_privileges("vdi_desktop_pool_manage_desktops")
    render :update do |page|
      page.redirect_to :controller =>request.parameters[:controller], :action => 'manage_desktops', :id=>params[:id]      # redirect to build the retire screen
    end
  end
  hide_action :vdi_desktop_pool_manage_desktops

  private ########

  def create_update
    return unless load_edit("vdp_edit__#{params[:id] ? params[:id] : "new"}")
    get_form_vars
    case params[:button]
      when "cancel"
        msg = @record.id ? I18n.t("flash.edit.cancelled", :model=>ui_lookup(:table=>self.class.table_name), :name=>@record.name) :
              I18n.t("flash.add.cancelled", :model=>ui_lookup(:table => self.class.table_name))
        session[:edit] = nil  # clean out the saved info
        render :update do |page|
          if @record.id
            page.redirect_to :action=>@lastaction, :flash_msg=>msg, :id=>@record.id, :escape=>false
          else
            page.redirect_to :action=>@lastaction, :flash_msg=>msg, :escape=>false
          end
        end
      when "add","save"
        assert_privileges("vdi_desktop_pool_#{@record.id ? "edit" : "new"}")
        if @edit[:new][:name].nil? || @edit[:new][:name] == ""
          add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
        end
        if @flash_array != nil
          @in_a_form = true
          if @record.id
            drop_breadcrumb( {:name=>"Edit #{ui_lookup( :table => self.class.table_name )} #{@record.name}", :url=>"/#{self.class.table_name}/new"} )
          else
            drop_breadcrumb( {:name=>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
          end

          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
          return
        end
        options = set_record_vars
        errors = @record.id ? @record.modify_desktop_pool(options) : VdiDesktopPool.create_desktop_pool(options)
        if errors
          add_flash(errors,:error)
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        else
          task = @record.id ? "Edit" : "Add"
          msg = I18n.t("flash.record.task_initiated", :model=>ui_lookup(:table=>self.class.table_name), :task=>task)
          render :update do |page|
            if @record.id
              page.redirect_to :action=>@lastaction, :flash_msg=>msg, :id=>@record.id, :escape=>false
            else
              page.redirect_to :action=>@lastaction, :flash_msg=>msg, :escape=>false
            end
          end
        end
      when "reset"
        edit
        add_flash(I18n.t("flash.edit.reset"), :warning)
        @in_a_form = true
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page.redirect_to :action=>'edit', :id=>@record.id.to_s
        end
    end
  end

  # Get variables from edit form
  def get_form_vars
    @record = @edit[:vdp_id] ? VdiDesktopPool.find_by_id(from_cid(@edit[:vdp_id])) :
                            VdiDesktopPool.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:enabled] = params[:enabled] == "1" ? true : false if params[:enabled]
    @edit[:new][:vdi_farm_id] = params[:vdi_farm_id] == "" ? nil : params[:vdi_farm_id] if params[:vdi_farm_id]
    #reset these, incase selected farm doesnt have any emses or if farm selection has changed
    if params[:vdi_farm_id]
      @edit[:new][:ems_id] = @edit[:emses] = nil
      @edit[:behaviors] = nil
      @edit[:new][:assignment_behavior] = nil
    end
    #add ems pull down only for new records
    if !@record.id && @edit[:new][:vdi_farm_id]
      farm = VdiFarm.find_by_id(@edit[:new][:vdi_farm_id])
      @edit[:new][:use_ssl] = true if @edit[:new][:use_ssl].nil?
      if !farm.allowed_emses.nil?
        @edit[:emses] = Array.new
        farm.allowed_emses.sort{|a,b|a.name.downcase<=>b.name.downcase}.each do |ems|
          @edit[:emses].push([ems.name,ems.id])
        end
      end
      if !farm.allowed_assignment_behaviors.nil?
        @edit[:behaviors] = Array.new
        farm.allowed_assignment_behaviors.sort.each do |ab|
          @edit[:behaviors].push([ab[1],ab[0]])
        end
      end
    end
    #set this here, since there is no pulldown on the screen to make selection if there is only single value
    @edit[:new][:assignment_behavior] = @edit[:behaviors][0].last if @edit[:behaviors] && @edit[:behaviors].length == 1
    @edit[:new][:assignment_behavior] = params[:assignment_behavior] == "" ? nil : params[:assignment_behavior] if params[:assignment_behavior]
    @edit[:new][:ems_id] = params[:ems_id] == "" ? nil : params[:ems_id] if params[:ems_id]
    @edit[:new][:use_ssl] = params[:use_ssl] == "1" ? true : false if params[:use_ssl]
  end


  # Set form variables for edit
  def set_form_vars
    @edit              = Hash.new
    @edit[:vdp_id]   = @record.id
    @edit[:key]        = "vdp_edit__#{@record.id || "new"}"
    @edit[:new]        = Hash.new
    @edit[:current]    = Hash.new

    @edit[:new][:name] = @record.name
    @edit[:new][:description]  = @record.description
    @edit[:new][:enabled] = !@record.enabled.nil? ? @record.enabled : true
    @edit[:new][:vdi_farm_id] = @record.vdi_farm ? @record.vdi_farm.id : nil
    @edit[:farm] = @record.vdi_farm.name if @record.vdi_farm
    @edit[:farms] = Array.new
    VdiFarm.find(:all).sort{|a,b|a.name.downcase<=>b.name.downcase}.each do |farm|
      @edit[:farms].push([farm.name,farm.id])
    end
    @edit[:new][:ems_id] = @record.ext_management_system ? @record.ext_management_system.id : nil
    @edit[:new][:assignment_behavior] = @record.assignment_behavior ? @record.assignment_behavior : nil
    @edit[:ems] = @record.ext_management_system.name if @record.ext_management_system
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit]  = @edit
  end

  # Set record variables to new values
  def set_record_vars
    options = Hash.new
    options[:name] = @edit[:new][:name]
    options[:description] = @edit[:new][:description]
    options[:enabled] = @edit[:new][:enabled]
    options[:vdi_farm_id] = @edit[:new][:vdi_farm_id]
    options[:ext_management_system_id] = @edit[:new][:ems_id] if @edit[:new][:ems_id]
    options[:use_ssl] = @edit[:new][:use_ssl] if @edit[:new][:ems_id] && !@edit[:new][:use_ssl].nil?
    options[:assignment_behavior] = @edit[:new][:assignment_behavior] if @edit[:new][:assignment_behavior]
    return options
  end

  def manage_desktops_get_form_vars
    if params[:button]
      move_cols_right if params[:button] == "right"
      move_cols_left  if params[:button] == "left"
    end
  end

  def manage_desktops_set_form_vars
    @edit           = Hash.new
    record = VdiDesktopPool.find_by_id(params[:id])
    @edit[:rec_id]   = record.id
    @edit[:key]     = "dp_edit__#{record.id}"
    @edit[:new]     = Hash.new
    @edit[:current] = Hash.new
    @edit[:new][:assigned_items] = Array.new
    record.vdi_desktops.sort{|a,b| a.name.to_s.downcase <=> b.name.to_s.downcase}.each do |desktop|
      @edit[:new][:assigned_items].push([desktop.name,desktop.id])
    end
    @edit[:new][:assigned_items].sort!
    @edit[:new][:available_items] = Array.new
    VdiDesktop.find(:all, :conditions=> ["vdi_desktop_pool_id is NULL"]).sort{|a,b| a.name.to_s.downcase <=> b.name.to_s.downcase}.each do |desktop|
      @edit[:new][:available_items].push([desktop.name,desktop.id])
    end
    @edit[:new][:available_items].sort!
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit]  = @edit
  end

  def manage_desktops_set_record_vars
    desktops = Array.new
    @edit[:new][:assigned_items].each do |item|
      desktops.push(VdiDesktop.find_by_id(item.last))
    end
   # @dp.vdi_desktops = desktops
    @dp.vdi_desktops.replace(desktops)
  end

end
