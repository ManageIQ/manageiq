class VdiDesktopController < VdiBaseController

  def index
    process_index
  end

  def button
    unmark_vdi if params[:pressed] == "vdi_desktop_unmark_vdi"
    vdi_desktop_user_assign if params[:pressed] == "vdi_desktop_user_assign"

    # return, let buttons method handle everything
    return if ["vdi_desktop_unmark_vdi"].include?(params[:pressed])
  end

  def show
    process_show(
      'vdi_user'    => :vdi_users
    )
  end

  def show_list
    process_show_list
  end

  def vdi_desktop_user_assign
    assert_privileges("vdi_desktop_user_assign")
    manage_user_assignment
  end

  def manage_user_assignment
    @sb[:selected_desktop_id] = params[:id]
    render :update do |page|
      page.redirect_to :controller =>request.parameters[:controller], :action => 'manage_users'     # redirect to build the manage user screen
    end
  end

  # Build the manage user assignment screen
  def manage_users
    case params[:button]
      when "cancel"
        flash = I18n.t("flash.edit.user_assignment_cancelled")
        redirect_to :action=>"show", :id=>@sb[:selected_desktop_id], :flash_msg=>flash, :escape=>false
        return
      when "save"
        return unless load_edit("assign_edit__new")
        assign_get_form_vars
        #items to be assigned to selected_items
        assign_items = assign_set_record_vars
        desktop = VdiDesktop.find_by_id(@sb[:selected_desktop_id])
        desktop.manage_users(assign_items)
        flash = I18n.t("flash.edit.user_assignment_initiated")
        redirect_to :action=>"show", :id=>@sb[:selected_desktop_id], :flash_msg=>flash, :escape=>false
        return
      else
        add_flash(I18n.t("flash.edit.reset"), :warning) if params[:button] == "reset"
        @gtl_url = "/manage_users?"
        title = "Manage VDI User assignments"
        drop_breadcrumb( {:name=>title, :url=>"/manage_users"} )
        manage_user_build_screen
        @edit[:current] = copy_hash(@edit[:new])
        session[:edit] = @edit
        @in_a_form = true
        render :action=>"show"
    end
  end

  def manage_user_build_screen
    @edit = Hash.new
    @edit[:key] = "assign_edit__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    @edit[:new][:assigned_items] = Array.new
    @manage_users = true
    desktop = VdiDesktop.find_by_id(@sb[:selected_desktop_id])
    desktop.vdi_users.each do |u|
      @edit[:new][:assigned_items].push([u.name,u.id])      # Single User, set despktop pools it's assigned to
    end
    @edit[:new][:available_items] = Array.new
    desktop.allowed_vdi_users.each do |u|
      @edit[:new][:available_items].push([u.name,u.id]) if !@edit[:new][:assigned_items].include?([u.name,u.id])
    end
    @edit[:new][:available_items].sort!
    @edit[:new][:assigned_items].sort!
    @in_a_form = true
  end
end
