module OpsController::Settings::Zones
  extend ActiveSupport::Concern

  def zone_edit
    case params[:button]
    when "cancel"
      @edit = nil
      @zone = Zone.find_by_id(session[:edit][:zone_id]) if session[:edit] && session[:edit][:zone_id]
      add_flash((@zone && @zone.id) ? _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:table=>"miq_zone"), :name=>@zone.name} :
          _("Add of new %s was cancelled by the user") % ui_lookup(:table=>"miq_zone"))
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    when "save", "add"
      assert_privileges("zone_#{params[:id] ? "edit" : "new"}")
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("zone_edit__#{id}","replace_cell__explorer")
      @zone = @edit[:zone_id] ? Zone.find_by_id(@edit[:zone_id]) : Zone.new
      if @edit[:new][:name] == ""
        add_flash(_("%s is required") % "Zone name", :error)
      end
      if @edit[:new][:description] == ""
        add_flash(_("%s is required") % "Description", :error)
      end
      if @flash_array != nil
        replace_right_cell("ze")
        return
      end
      #zone = @zone.id.blank? ? Zone.new : Zone.find(@zone.id)  # Get new or existing record
      zone_set_record_vars(@zone)
      if valid_record?(@zone) && @zone.save
        AuditEvent.success(build_created_audit(@zone, @edit))
        add_flash(I18n.t("#{params[:button] == "save" ? "flash.edit.saved" : "flash.add.added"}",
                        :model=>ui_lookup(:model=>"Zone"),
                        :name=>@edit[:new][:name]))
        @edit = nil
        self.x_node = params[:button] == "save" ?
              "z-#{@zone.id}" : "xx-z"
        get_node_info(x_node)
        replace_right_cell("root",[:settings,:diagnostics,:analytics])
      else
        @in_a_form = true
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        @zone.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("ze")
      end
    when "reset", nil # Reset or first time in
      zone_build_edit_screen
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("ze")
    end
  end

  # AJAX driven routine to delete a zone
  def zone_delete
    assert_privileges("zone_delete")
    zone = Zone.find(params[:id])
    zonename = zone.name
    audit = {:event=>"zone_record_delete", :message=>"[#{zone.name}] Record deleted", :target_id=>zone.id, :target_class=>"Zone", :userid => session[:userid]}
    begin
      zone.destroy
    rescue StandardError=>bang
      add_flash("#{bang}", :error)
      zone.errors.each { |field,msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      self.x_node = "z-#{zone.id}"
      get_node_info(x_node)
    else
      add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>ui_lookup(:model=>"Zone"), :name=>zonename})
      @sb[:active_tab] = "settings_list"
      self.x_node = "xx-z"
      get_node_info(x_node)
      replace_right_cell(x_node,[:settings,:diagnostics,:analytics])
    end
  end

    # AJAX driven routine to check for changes in ANY field on the user form
  def zone_field_changed
    return unless load_edit("zone_edit__#{params[:id]}","replace_cell__explorer")
    zone_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace(@refresh_div, :partial=>@refresh_partial,
                    :locals=>{:type=>"zones", :action_url=>'zone_field_changed'}) if @refresh_div

      # checking to see if password/verify pwd fields either both have value or are both blank
      password_fields_changed = !(@edit[:new][:password].blank? ^ @edit[:new][:verify].blank?)

      if @changed != session[:changed]
        session[:changed] = @changed
        page << javascript_for_miq_button_visibility(@changed && password_fields_changed)
      else
        page << javascript_for_miq_button_visibility(password_fields_changed)
      end
    end
  end

  private

  # Set user record variables to new values
  def zone_set_record_vars(zone, mode = nil)
    zone.name = @edit[:new][:name]
    zone.description = @edit[:new][:description]
    zone.settings ||= Hash.new
    zone.settings[:proxy_server_ip] = @edit[:new][:proxy_server_ip]
    zone.settings[:concurrent_vm_scans] = @edit[:new][:concurrent_vm_scans]
    if @edit[:new][:ntp][:server]
      temp = Array.new
      @edit[:new][:ntp][:server].each{|svr| temp.push(svr) unless svr.blank?}
      zone.settings[:ntp] ||= Hash.new
      zone.settings[:ntp][:server] = temp
    end
    zone.update_authentication({:windows_domain => {:userid=>@edit[:new][:userid], :password=>@edit[:new][:password]}}, {:save => (mode != :validate) })
  end

  # Validate the zone record fields
  def valid_record?(zone)
    valid = true
    @edit[:errors] = Array.new
    if !zone.authentication_password.blank? && zone.authentication_userid.blank?
      @edit[:errors].push("User ID must be entered if Password is entered")
      valid = false
    end
    if @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push("Password and Verify Password fields do not match")
      valid = false
    end
    return valid
  end

  # Get variables from zone edit form
  def zone_get_form_vars
    @zone = @edit[:zone_id] ? Zone.find_by_id(@edit[:zone_id]) : Zone.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:proxy_server_ip] = params[:proxy_server_ip] if params[:proxy_server_ip]
    @edit[:new][:concurrent_vm_scans] = params[:max_scans].to_i if params[:max_scans]
    @edit[:new][:userid] = params[:userid] if params[:userid]
    @edit[:new][:password] = params[:password] if params[:password]
    @edit[:new][:verify] = params[:verify] if params[:verify]

    @edit[:new][:ntp][:server][0] = params[:ntp_server_1] if params[:ntp_server_1]
    @edit[:new][:ntp][:server][1] = params[:ntp_server_2] if params[:ntp_server_2]
    @edit[:new][:ntp][:server][2] = params[:ntp_server_3] if params[:ntp_server_3]
    set_verify_status
  end

  def zone_build_edit_screen
    @zone = params[:id] ? Zone.find(params[:id]) : Zone.new           # Get existing or new record
    zone_set_form_vars
    @in_a_form = true
    session[:changed] = false
  end

  # Set form variables for user add/edit
  def zone_set_form_vars
    @edit = Hash.new
    @edit[:zone_id] = @zone.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "zone_edit__#{@zone.id || "new"}"

    @edit[:new][:name] = @zone.name
    @edit[:new][:description] = @zone.description
    @edit[:new][:proxy_server_ip] = @zone.settings ? @zone.settings[:proxy_server_ip] : nil
    @edit[:new][:concurrent_vm_scans] = @zone.settings ? @zone.settings[:concurrent_vm_scans].to_i : 0

    @edit[:new][:userid] = @zone.authentication_userid(:windows_domain)
    @edit[:new][:password] = @zone.authentication_password(:windows_domain)
    @edit[:new][:verify] = @zone.authentication_password(:windows_domain)
    @edit[:new][:ntp] = @zone.settings[:ntp] if !@zone.settings.nil? && !@zone.settings[:ntp].nil?

    @edit[:new][:ntp] ||= Hash.new
    @edit[:new][:ntp][:server] ||= Array.new

    session[:verify_ems_status] = nil
    set_verify_status

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

end
