# Access Control Accordion methods included in OpsController.rb
module OpsController::OpsRbac
  extend ActiveSupport::Concern

  # Edit user or group tags
  def rbac_tags_edit
    case params[:button]
      when "cancel"
        rbac_edit_tags_cancel
      when "save", "add"
        assert_privileges("rbac_#{session[:tag_db] == "MiqGroup" ? "group" : "user"}_tags_edit")
        rbac_edit_tags_save
      when "reset", nil # Reset or first time in
        nodes = x_node.split('-')
        if nodes.first == "g" || nodes.last == "g"
          @_params[:tagging] = "MiqGroup"
        elsif nodes.first == "u" || nodes.last == "u"
          @_params[:tagging] = "User"
        end
        rbac_edit_tags_reset
    end
  end

  def rbac_change_tab
    render :update do |page|
      page << "miqSparkle(false);"
    end
  end

  def rbac_user_add
    assert_privileges("rbac_user_add")
    @_params[:typ] = "new"
    rbac_edit_reset('user', User)
  end

  def rbac_user_copy
    assert_privileges("rbac_user_copy")
    @_params[:typ] = "copy"
    rbac_edit_reset('user', User)
  end

  def rbac_user_edit
    assert_privileges("rbac_user_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('user')
    when 'save', 'add' then rbac_edit_save_or_add('user')
    when 'reset', nil  then rbac_edit_reset('user', User) # Reset or first time in
    end
  end

  def rbac_group_add
    assert_privileges("rbac_group_add")
    @_params[:typ] = "new"
    rbac_edit_reset('group', MiqGroup)
  end

  def rbac_group_edit
    assert_privileges("rbac_group_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('group')
    when 'save', 'add' then rbac_edit_save_or_add('group')
    when 'reset', nil  then rbac_edit_reset('group', MiqGroup) # Reset or first time in
    end
  end

  def rbac_role_add
    assert_privileges("rbac_role_add")
    @_params[:typ] = "new"
    rbac_edit_reset('role', MiqUserRole)
  end

  def rbac_role_copy
    assert_privileges("rbac_role_copy")
    @_params[:typ] = "copy"
    rbac_edit_reset('role', MiqUserRole)
  end

  def rbac_role_edit
    assert_privileges("rbac_role_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('role')
    when 'save', 'add' then rbac_edit_save_or_add('role', 'miq_user_role')
    when 'reset', nil  then rbac_edit_reset('role', MiqUserRole) # Reset or first time in
    end
  end

  # AJAX driven routines to check for changes in ANY field on the form
  def rbac_user_field_changed
    rbac_field_changed("user")
  end

  def rbac_group_field_changed
    rbac_field_changed("group")
  end

  def rbac_role_field_changed
    rbac_field_changed("role")
  end

  def rbac_user_delete
    assert_privileges("rbac_user_delete")
    users = Array.new
    unless params[:id] # showing a list
      ids = find_checked_items.collect{|r| from_cid(r.split("-").last)}
      users = User.find_all_by_id(ids).compact
      if users.empty?
        add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model=>ui_lookup(:model=>"User"), :name=>"Administrator"}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      else
        restricted_users = []
        users.each do |u|
          user = User.find(u)
          restricted_users.push(user) if rbac_user_delete_restriction?(user)
        end
        #deleting elements in temporary array, had to create temp array to hold id's to be delete, .each gets confused if i deleted them in above loop
        restricted_users.each do |u|
          rbac_restricted_user_delete_flash(u)
          users.delete(u)
        end
      end
      process_users(users, "destroy") unless users.empty?
    else # showing 1 user, delete it
      if params[:id] == nil || User.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % "User", :error)
      else
        user = User.find_by_id(params[:id])
        if rbac_user_delete_restriction?(user)
          rbac_restricted_user_delete_flash(user)
        else
          users.push(params[:id])
        end
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      process_users(users, "destroy") unless users.empty?
      self.x_node  = "xx-u"  # reset node to show list
    end
    get_node_info(x_node)
    replace_right_cell(x_node,[:rbac])
  end

  def rbac_role_delete
    assert_privileges("rbac_role_delete")
    roles = []
    if !params[:id] # showing a role list
      ids = find_checked_items.collect { |r| from_cid(r.split("-").last) }
      roles = MiqUserRole.find_all_by_id(ids)
      process_roles(roles, "destroy") unless roles.empty?
    else # showing 1 role, delete it
      if params[:id].nil? || MiqUserRole.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") %  "Role", :error)
      else
        roles.push(params[:id])
      end
      process_roles(roles, "destroy") unless roles.empty?
      self.x_node  = "xx-ur" if MiqUserRole.find_by_id(params[:id]).nil? # reset node to show list
    end
    get_node_info(x_node)
    replace_right_cell(x_node, [:rbac])
  end

  # Show the main Users/Groups/Roles list view
  def rbac_users_list
    rbac_list("user")
  end
  def rbac_groups_list
    rbac_list("group")
  end
  def rbac_roles_list
    rbac_list("role")
  end

  def rbac_group_delete
    assert_privileges("rbac_group_delete")
    groups = []
    if !params[:id] # showing a list
      ids = find_checked_items.collect { |r| from_cid(r.split("-").last) }
      groups = MiqGroup.find_all_by_id(ids)
      process_groups(groups, "destroy") unless groups.empty?
      self.x_node  = "xx-g"  # reset node to show list
    else # showing 1 group, delete it
      if params[:id].nil? || MiqGroup.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") %  "MiqGroup", :error)
      else
        groups.push(params[:id])
      end
      process_groups(groups, "destroy") unless groups.empty?
      self.x_node  = "xx-g" if MiqGroup.find_by_id(params[:id]).nil? # reset node to show list
    end
    get_node_info(x_node)
    replace_right_cell(x_node, [:rbac])
  end

  def rbac_group_seq_edit
    assert_privileges("rbac_group_seq_edit")
    case params[:button]
    when "cancel"
      @edit = nil
      add_flash(_("Edit Sequence of User Groups was cancelled by the user"))
      get_node_info(x_node)
      replace_right_cell(x_node)
    when "save"
      return unless load_edit("rbac_group_edit__seq", "replace_cell__explorer")
      err = false
      @edit[:new][:ldap_groups_list].each_with_index do |grp, i|
        group = MiqGroup.find_by_description(grp)
        group.sequence = i+1
        if group.save
          AuditEvent.success(build_saved_audit(group, params[:button] == "add"))
        else
          group.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          err = true
        end
      end
      if !err
        add_flash(_("User Group Sequence was saved"))
        @_in_a_form = false
        @edit = session[:edit] = nil  # clean out the saved info
        get_node_info(x_node)
        replace_right_cell(x_node)
      else
        drop_breadcrumb( {:name=>"Edit User Group Sequence", :url=>"/configuration/ldap_seq_edit"} )
        @in_a_form = true
        replace_right_cell("group_seq")
      end
    when "reset", nil # Reset or first time in
      rbac_group_seq_edit_screen
      @in_a_form = true
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("group_seq")
    end
  end

  def rbac_group_seq_edit_screen
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new][:ldap_groups] = MiqGroup.all(:order => "sequence ASC")  # Get the groups from the DB
    @edit[:new][:ldap_groups_list] = Array.new
    @edit[:new][:ldap_groups].each do |g|
      @edit[:new][:ldap_groups_list].push(g.description)
    end
    @edit[:key] = "rbac_group_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = "Editing Sequence of User Groups"
    @tabs = [ ["ldap_seq_edit", "Edit Sequence of User Groups"], ["ldap_seq_edit", "Edit Sequence of User Groups"] ]
    session[:edit] = @edit
    session[:changed] = false
  end

  def move_cols_up
    return unless load_edit("rbac_group_edit__seq", "replace_cell__explorer")
    if !params[:seq_fields] || params[:seq_fields].length == 0 || params[:seq_fields][0] == ""
      add_flash(_("No %s were selected to move up") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move up") % "fields", :error)
    else
      if first_idx > 0
        @edit[:new][:ldap_groups_list][first_idx..last_idx].reverse.each do |field|
          pulled = @edit[:new][:ldap_groups_list].delete(field)
          @edit[:new][:ldap_groups_list].insert(first_idx - 1, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "ldap_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def move_cols_down
    return unless load_edit("rbac_group_edit__seq", "replace_cell__explorer")
    if !params[:seq_fields] || params[:seq_fields].length == 0 || params[:seq_fields][0] == ""
      add_flash(_("No %s were selected to move down") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move down") % "fields", :error)
    else
      if last_idx < @edit[:new][:ldap_groups_list].length - 1
        insert_idx = last_idx + 1   # Insert before the element after the last one
        insert_idx = -1 if last_idx == @edit[:new][:ldap_groups_list].length - 2 # Insert at end if 1 away from end
        @edit[:new][:ldap_groups_list][first_idx..last_idx].each do |field|
          pulled = @edit[:new][:ldap_groups_list].delete(field)
          @edit[:new][:ldap_groups_list].insert(insert_idx, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "ldap_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def selected_consecutive?
    first_idx = last_idx = 0
    @edit[:new][:ldap_groups_list].each_with_index do |nf,idx|
      first_idx = idx if nf == params[:seq_fields].first
      if nf == params[:seq_fields].last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > params[:seq_fields].length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  def rbac_group_user_lookup_field_changed
    return unless load_edit("rbac_group_edit__#{params[:id]}", "replace_cell__explorer")
    @edit[:new][:user]     = params[:user]     if params[:user]
    @edit[:new][:user_id]  = params[:user_id]  if params[:user_id]
    @edit[:new][:user_pwd] = params[:password] if params[:password]
  end

  def rbac_group_user_lookup
    rbac_group_user_lookup_field_changed
    if @edit[:new][:user].nil? || @edit[:new][:user] == ""
      add_flash(_("%s must be entered to perform LDAP Group Look Up") % "User", :error)
    end
    if @edit[:new][:user_id].nil? || @edit[:new][:user_id] == ""
      add_flash(_("%s must be entered to perform LDAP Group Look Up") % "User Id", :error)
    end
    if @edit[:new][:user_pwd].nil? || @edit[:new][:user_pwd] == ""
      add_flash(_("%s must be entered to perform LDAP Group Look Up") % "User Password", :error)
    end
    if @flash_array != nil
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div",:partial=>"layouts/flash_msg")
      end
    else
      @record = MiqGroup.find_by_id(@edit[:group_id])
      @sb[:roles] = @edit[:roles]
      begin
        @edit[:ldap_groups_by_user] = MiqGroup.get_ldap_groups_by_user(@edit[:new][:user],@edit[:new][:user_id],@edit[:new][:user_pwd]) # Get the users from the DB
      rescue StandardError => bang
        @edit[:ldap_groups_by_user] = Array.new
        add_flash(_("Error during '%s': ") % "LDAP Group Look Up" << bang.message, :error)
        render :update do |page|                    # Use JS to update the display
          page.replace("flash_msg_div",:partial=>"layouts/flash_msg")
          page.replace("ldap_user_div",:partial=>"ldap_auth_users")
        end
      else
        render :update do |page|                    # Use JS to update the display
          page.replace("ldap_user_div",:partial=>"ldap_auth_users")
        end
      end
    end
  end

  private ############################

  def rbac_user_delete_restriction?(user)
    ["admin", session[:userid]].include?(user.userid)
  end

  def rbac_restricted_user_delete_flash(user)
    if user.userid == "admin"
      add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "User"), :name => user.name}, :error)
    elsif user.userid == session[:userid]
      add_flash(_("Current %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "User"), :name => user.name}, :error)
    end
  end

  def rbac_edit_tags_reset
    @object_ids = find_checked_items
    if params[:button] == "reset"
      id = params[:id] if params[:id]
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
      @object_ids = @edit[:object_ids]
      session[:tag_db] = @tagging = @edit[:tagging]
    else
      @object_ids[0] = params[:id] if @object_ids.blank? && params[:id]
      session[:tag_db] = @tagging = params[:tagging]
    end

    @gtl_type = "list"  # No quad icons for user/group list views
    rbac_tags_set_form_vars
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning)  if params[:button] == "reset"
    @sb[:pre_edit_node] = x_node  unless params[:button]  # Save active tree node before edit
    @right_cell_text = _("Editing %{model} for \"%{name}\"") % {:name=>ui_lookup(:models=>@tagging), :model=>"#{session[:customer_name]} Tags"}
    replace_right_cell("root")
  end

  # Set form vars for tag editor
  def rbac_tags_set_form_vars
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:key] = "#{session[:tag_db]}_edit_tags__#{@object_ids[0]}"
    @edit[:object_ids] = @object_ids
    @edit[:tagging] = @tagging

    tag_edit_build_screen
    build_targets_hash(@tagitems)

    @edit[:current] = copy_hash(@edit[:new])
  end

  def rbac_edit_tags_cancel
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
    add_flash(_("%s was cancelled by the user") % "Tag Edit")
    self.x_node  = @sb[:pre_edit_node]
    get_node_info(x_node)
    @edit = nil # clean out the saved info
    replace_right_cell(@nodetype)
  end

  def rbac_edit_tags_save
    tagging_edit_tags_save_and_replace_right_cell
  end

  def rbac_edit_cancel(what)
    key = what.to_sym
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("rbac_#{what}_edit__#{id}", "replace_cell__explorer")
    case key
    when :role
      record_id = @edit[:role_id]
    when :group
      record_id = @edit[:group_id]
    when :user
      record_id = @edit[:user_id]
    end
    add_flash(record_id ? _("Edit of %s was cancelled by the user") % what.titleize : _("Add of new %s was cancelled by the user") % what.titleize)
    self.x_node  = @sb[:pre_edit_node]
    get_node_info(x_node)
    @edit = nil # clean out the saved info
    replace_right_cell(@nodetype)
  end

  def rbac_edit_reset(what, klass)
    key = what.to_sym
    obj = find_checked_items
    obj[0] = params[:id] if obj.blank? && params[:id]
    record = klass.find_by_id(from_cid(obj[0])) if obj[0]

    if [:group,:role].include?(key) && record && record.read_only && params[:typ] != "copy"
      add_flash(_("Read Only %{model} \"%{name}\" can not be edited") % {:model=>key == :role ? ui_lookup(:model=>"MiqUserRole") : ui_lookup(:model=>"MiqGroup"), :name=>key == :role ? record.name : record.description}, :warning)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
      return
    end

    case params[:typ]
    when "new"
      @record = klass.new                 # New record
      if key == :role
        @record.miq_product_features = [MiqProductFeature.find_by_identifier(MiqProductFeature.feature_root)]
      end
    when "copy"
      @record = record.clone                # Copy existing record
      case key
      when :user
        @record.current_group        = record.current_group
      when :group
        @record.miq_user_role        = record.miq_user_role
      when :role
        @record.miq_product_features = @record_features = record.miq_product_features
        @record.read_only            = false
      end
    else
      @record = record                      # Use existing record
    end
    @sb[:typ] = params[:typ]
    self.send("rbac_#{what}_set_form_vars")
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning)  if params[:button] == "reset"
    @sb[:pre_edit_node] = x_node  unless params[:button]  # Save active tree node before edit
    if @edit["#{key}_id".to_sym]
      caption = (key == :group) ? @record.description : @record.name
      @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name=>caption, :model=>what.titleize}
    else
      @right_cell_text = _("Adding a new %s") % what.titleize
    end
    replace_right_cell(x_node)
  end

  def rbac_edit_save_or_add(what, rbac_suffix = what)
    key         = what.to_sym
    id          = params[:id] || "new"
    add_pressed = params[:button] == "add"

    return unless load_edit("rbac_#{what}_edit__#{id}", "replace_cell__explorer")

    record = case key
             when :role  then @edit[:role_id]  ? MiqUserRole.find_by_id(@edit[:role_id]) : MiqUserRole.new
             when :group then @edit[:group_id] ? MiqGroup.find_by_id(@edit[:group_id])   : MiqGroup.new
             when :user  then @edit[:user_id]  ? User.find_by_id(@edit[:user_id])        : User.new
             end

    self.send("rbac_#{what}_set_record_vars", record)
    self.send("rbac_#{what}_validate?")

    if record.valid? && !flash_errors? && record.save
      AuditEvent.success(build_saved_audit(record, add_pressed))
      subkey = (key == :group) ? :description : :name
      add_flash(_("%{model} \"%{name}\" was saved") % {:model => what.titleize, :name => @edit[:new][subkey]})
      @edit = session[:edit] = nil  # clean out the saved info
      if add_pressed
        suffix = case rbac_suffix
                 when "group"         then "g"
                 when "miq_user_role" then "ur"
                 when "user"          then "u"
                 end
        self.x_node = "xx-#{suffix}" # reset node to show list
        self.send("rbac_#{what.pluralize}_list")
      end
      # Get selected Node
      get_node_info(x_node)
      replace_right_cell(x_node, [:rbac])
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      record.errors.each { |field, msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      render_flash
    end
  end

  # Show the main Users/Gropus/Roles list views
  def rbac_list(rec_type)
    rbac_build_list(rec_type)
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"rbac_#{rec_type.pluralize}_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"
      end
    end
  end

  # Create the view and associated vars for the rbac list
  def rbac_build_list(rec_type)
    @lastaction = "rbac_#{rec_type}s_list"
    @force_no_grid_xml = true
    @gtl_type = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session["rbac_#{rec_type}_sortcol"] == nil ? 0 : @sb["rbac_#{rec_type}_sortcol"].to_i
    @sortdir = session["rbac_#{rec_type}_sortdir"] == nil ? "ASC" : @sb["rbac_#{rec_type}_sortdir"]

    # Get the records (into a view) and the paginator
    @view, @pages = case rec_type
                      when "user"
                        get_view(User, :named_scope=>:in_my_region)
                      when "group"
                        get_view(MiqGroup)
                      when "role"
                        get_view(MiqUserRole)
                    end

    @current_page = @pages[:current] if @pages != nil # save the current page number
    @sb["rbac_#{rec_type}_sortcol"] = @sortcol
    @sb["rbac_#{rec_type}_sortdir"] = @sortdir
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def rbac_field_changed(rec_type)
    id = params[:id].split('__').first    # Get the record id
    id = from_cid(id) unless id == "new" || id == "seq" # Decompress id if not "new"
    return unless load_edit("rbac_#{rec_type}_edit__#{id}", "replace_cell__explorer")

    case rec_type
    when "user"  then rbac_user_get_form_vars
    when "group" then tree_name = rbac_group_get_form_vars
    when "role"  then rbac_role_get_form_vars
    end

    changed = (@edit[:new] != @edit[:current])

    render :update do |page|              # Use JS to update the display
      if %w(up down).include?(params[:button])
        page.replace("flash_msg_div", :partial => "layouts/flash_msg") unless @refresh_div && @refresh_div != "column_lists"
        page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      else
        # only do following for groups
        if x_node.split("-").first == "g" || x_node == "xx-g"
          page.replace(@refresh_div,
                       :partial => @refresh_partial,
                       :locals  => {:type => "classifications", :action_url => 'rbac_group_field_changed'}) if @refresh_div

          # Only update description field value if ldap group user field was selected
          page << "$('#description').val('#{j_str(@edit[:new][:description])}');" if params[:ldap_groups_user]
          page << javascript_for_tree_checkbox_clicked(tree_name) if params[:check] && tree_name

          # don't do anythingto lookup box when checkboxes on the right side are checked
          page << set_element_visible('group_lookup', @edit[:new][:lookup]) unless params[:check]
        end
      end
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Common User button handler routine
  def process_groups(groups, task)
    process_elements(groups, MiqGroup, task)
  end

  # Common User button handler routine
  def process_users(users, task)
    process_elements(users, User, task)
  end

  # Common Role button handler routine
  def process_roles(roles, task)
    process_elements(roles, MiqUserRole, task)
  end

  # Build the main Access Control tree
  def rbac_build_tree
    TreeBuilderOpsRbac.new("rbac_tree", "rbac", @sb)
  end

  # Get information for an access control node
  def rbac_get_info(nodetype)
    node, id = nodetype.split("-")
    case node
      when "xx"
        case id
          when "u"
            @right_cell_text = _("%{typ} %{model}") % {:typ=>"Access Control", :model=>ui_lookup(:models=>"User")}
            rbac_users_list
          when "g"
            @right_cell_text = _("%{typ} %{model}") % {:typ=>"Access Control", :model=>ui_lookup(:models=>"MiqGroup")}
            rbac_groups_list
          when "ur"
            @right_cell_text = _("%{typ} %{model}") % {:typ=>"Access Control", :model=>ui_lookup(:models=>"MiqUserRole")}
            rbac_roles_list
        end
      when "u"
        @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"User"), :name=>User.find_by_id(from_cid(id)).name}
        rbac_user_get_details(id)
      when "g"
        @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqGroup"), :name=>MiqGroup.find_by_id(from_cid(id)).description}
        rbac_group_get_details(id)
      when "ur"
        @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqUserRole"), :name=>MiqUserRole.find_by_id(from_cid(id)).name}
        rbac_role_get_details(id)
      else  # Root node
        @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>"Access Control", :name=>"#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]", :model=>ui_lookup(:model=>"MiqRegion")}
        @temp[:users_count] = User.in_my_region.count
        @temp[:groups_count] = MiqGroup.count
        @temp[:roles_count] = MiqUserRole.count
    end
  end

  def rbac_user_get_details(id)
    @edit = nil
    @record = @user = User.find_by_id(from_cid(id))
    get_tagdata(@user)
  end

  def rbac_group_get_details(id)
    @edit = nil
    @record = @group = MiqGroup.find_by_id(from_cid(id))
    get_tagdata(@group)
    # Build the belongsto filters hash
    @temp[:belongsto] = Hash.new
    @group.get_belongsto_filters.each do |b|            # Go thru the belongsto tags
      bobj = MiqFilter.belongsto2object(b)            # Convert to an object
      next unless bobj
      @temp[:belongsto][bobj.class.to_s + "_" + bobj.id.to_s] = b # Store in hash as <class>_<id> string
    end
    @temp[:filters] = Hash.new
    # Build the managed filters hash
    [@group.get_managed_filters].flatten.each do |f|
      @temp[:filters][f.split("/")[-2] + "-" + f.split("/")[-1]] = f
    end
    rbac_build_myco_tree                              # Build the MyCompanyTags tree for this user
    build_belongsto_tree(@temp[:belongsto].keys)  # Build the Hosts & Clusters tree for this user
    build_belongsto_tree(@temp[:belongsto].keys, true)  # Build the VMs & Templates tree for this user
  end

  def rbac_role_get_details(id)
    @edit = nil
    @record = @role = MiqUserRole.find_by_id(from_cid(id))
    @role_features = @role.feature_identifiers.sort
    @temp[:features_tree] = rbac_build_features_tree
  end

  def rbac_build_features_tree
    @role = @sb[:typ] == "copy" ? @record.dup : @record if @role.nil?     #if on edit screen use @record
    root_feature = MiqProductFeature.feature_root
    root = MiqProductFeature.feature_details(root_feature)
    root_node = {
      :key      => "#{@role.id ? to_cid(@role.id) : "new"}__#{root_feature}",
      :icon     => "feature_node.png",
      :title    => root[:name],
      :tooltip  => root[:description] || root[:name],
      :addClass => "cfme-cursor-default",
      :expand   => true,
      :select   => @role_features.include?(root_feature)
    }

    top_nodes = []
    Menu::Manager.each_feature_title_with_subitems do |feature_title, subitems|
      t_kids = []
      t_node = {
        :key     => "#{@role.id ? to_cid(@role.id) : "new"}___tab_#{feature_title}",
        :icon    => "feature_node.png",
        :title   => feature_title,
        :tooltip => feature_title + " Main Tab"
      }

      subitems.each do |f| # Go thru the features of this tab
        f_tab = f.ends_with?("_accords") ? f.split("_accords").first : f  # Remove _accords suffix if present, to get tab feature name
        next unless MiqProductFeature.feature_exists?(f_tab)
        feature = rbac_features_tree_add_node(f_tab, t_node[:key], root_node[:select])
        t_kids.push(feature) unless feature.nil?
      end

      if root_node[:select]                 # Root node is checked
        t_node[:select] = true
      elsif !t_kids.empty?                  # If kids are present
        full_chk = (t_kids.collect{|k| k if k[:select]}.compact).length
        part_chk = (t_kids.collect{|k| k unless k[:select]}.compact).length
        if full_chk == t_kids.length
          t_node[:select] = true            # All kids are checked
        elsif full_chk > 0 || part_chk > 0
          t_node[:select] = false           # Some kids are checked or partially checked
        end
      end

      t_node[:children] = t_kids unless t_kids.empty?
      #only show storage node if product setting is set to show the nodes
      case feature_title.downcase
        when "storage"; top_nodes.push(t_node) if get_vmdb_config[:product][:storage]
        else            top_nodes.push(t_node)
      end
    end
    root_node[:children] = top_nodes unless top_nodes.empty?
    return [root_node].to_json
  end

  def rbac_features_tree_add_node(feature, pid, parent_checked = false)
    details = MiqProductFeature.feature_details(feature)
    unless details[:hidden]
      f_node = {}
      f_kids = []                             # Array to hold node children
      f_node[:key] = "#{@role.id ? to_cid(@role.id) : "new"}__#{feature}"
      f_node[:icon] = "feature_#{details[:feature_type]}.png"
      f_node[:title] = details[:name]
      f_node[:tooltip] = details[:description] || details[:name]
      f_node[:hideCheckbox] = true if details[:protected]

      # Go thru the features children
      MiqProductFeature.feature_children(feature).each do |f|
        feat = rbac_features_tree_add_node(f,
                                           f_node[:key],
                                           parent_checked || @role_features.include?(feature)) if f
        f_kids.push(feat) if feat
      end
      f_node[:children] = f_kids unless f_kids.empty?             # Add in the node's children, if any

      if parent_checked ||                  # Parent is checked
          @role_features.include?(feature)  # This feature is checked
        f_node[:select] = true
      elsif !f_kids.empty?                  # If kids are present
        full_chk = (f_kids.collect { |k| k if k[:select] }.compact).length
        part_chk = (f_kids.collect { |k| k unless k[:select] }.compact).length
        if full_chk == f_kids.length
          f_node[:select] = true            # All kids are checked
        elsif full_chk > 0 || part_chk > 0
          f_node[:select] = false         # Some kids are checked
        end
      end
      f_node
    end
  end

  # Set form variables for role edit
  def rbac_user_set_form_vars
    @edit = Hash.new
    @edit[:user_id] = @record.id if @sb[:typ] != "copy"
    @user = @sb[:typ] == "copy" ? @record.dup : @record # Save a shadow copy of the record if record is being copied
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "rbac_user_edit__#{@edit[:user_id] || "new"}"

    @edit[:new][:name] = @user.name
    @edit[:new][:userid] = @user.userid
    @edit[:new][:email] = @user.email.to_s
    @edit[:new][:password] = @user.password
    @edit[:new][:password2] = @user.password

    @edit[:groups] = Array.new
    MiqGroup.all.sort{|a,b| a.description.downcase<=>b.description.downcase}.each do | g |
      @edit[:groups].push([g.description, g.id])
    end
    @edit[:new][:group] = @user.current_group ? @user.current_group.id : nil

    @edit[:current] = copy_hash(@edit[:new])
  end

  # Get variables from user edit form
  def rbac_user_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:userid] = params[:userid].strip if params[:userid]
    @edit[:new][:email] = params[:email].strip if params[:email]
    @edit[:new][:group] = params[:chosen_group] if params[:chosen_group]

    @edit[:new][:password] = params[:password] if params[:password]
    @edit[:new][:password2] = params[:password2] if params[:password2]
  end

  # Set user record variables to new values
  def rbac_user_set_record_vars(user)
    user.name       = @edit[:new][:name]
    user.userid     = @edit[:new][:userid]
    user.email      = @edit[:new][:email]
    user.miq_groups = [MiqGroup.find_by_id(@edit[:new][:group])].compact
    user.password   = @edit[:new][:password]
  end

  # Validate some of the user fields
  def rbac_user_validate?
    valid = true
    if @edit[:new][:password] != @edit[:new][:password2]
      add_flash(_("Password/Verify Password do not match"), :error)
      valid = false
    end
    if @edit[:new][:group].blank?
      add_flash(_("A User must be assigned to a Group"), :error)
      valid = false
    end
    valid
  end

  # Get variables from group edit form
  def rbac_group_get_form_vars
    if %w(up down).include?(params[:button])
      move_cols_up   if params[:button] == "up"
      move_cols_down if params[:button] == "down"
    else
      @edit[:new][:description] = params[:ldap_groups_user] if params[:ldap_groups_user]
      @edit[:new][:description] = params[:description]      if params[:description]
      @edit[:new][:role]        = params[:group_role]       if params[:group_role]
      @edit[:new][:lookup]      = (params[:lookup] == "1")  if params[:lookup]
      @edit[:new][:user]        = params[:user]             if params[:user]
      @edit[:new][:user_id]     = params[:user_id]          if params[:user_id]
      @edit[:new][:user_pwd]    = params[:password]         if params[:password]
    end

    if params[:check]                               # User checked/unchecked a tree node
      if params[:tree_typ] == "myco"                # MyCompany tag checked
        if params[:check] == "0"                    #   unchecked
          @edit[:new][:filters].delete(params[:id].split('___').last)   #     Remove the tag from the filters array
        else                                        #   checked
          cat, tag = params[:id].split('___').last.split("-")         #     Get the category and tag
          @edit[:new][:filters][params[:id].split('___').last] = "/managed/#{cat}/#{tag}" # Put them in the hash
        end
      else                                          # Belongsto tag checked
        if params[:check] == "0"                    #   unchecked
          @edit[:new][:belongsto].delete(params[:id].split('___').last) #     Remove the tag from the belongsto hash
        else                                        #   checked
          objc, objid = params[:id].split('___').last.split("_")      #     Get the object class and id
          tobj = objc.constantize.find(objid)       #     Get the record
          @edit[:new][:belongsto][params[:id].split('___').last] = MiqFilter.object2belongsto(tobj) # Put the tag into the belongsto hash
        end
      end
    end

    params[:tree_typ] ? params[:tree_typ] + "_tree" : nil
  end

  # Set form variables for user add/edit
  def rbac_group_set_form_vars
    @assigned_filters = Array.new
    @edit = Hash.new
    @group = @record
    @edit[:group_id] = @record.id
    @edit[:new] = Hash.new
    @edit[:key] = "rbac_group_edit__#{@edit[:group_id] || "new"}"
    @edit[:new][:filters] = Hash.new
    @edit[:new][:belongsto] = Hash.new
    @edit[:ldap_groups_by_user] = Array.new

    @edit[:new][:description] = @group.description
#   @edit[:new][:role] = @group.miq_user_role.id

    # Build the managed filters hash
    [@group.get_managed_filters].flatten.each do |f|
      @edit[:new][:filters][f.split("/")[-2] + "-" + f.split("/")[-1]] = f
    end

    # Build the belongsto filters hash
    @group.get_belongsto_filters.each do |b|            # Go thru the belongsto tags
      bobj = MiqFilter.belongsto2object(b)            # Convert to an object
      next unless bobj
      @edit[:new][:belongsto][bobj.class.to_s + "_" + bobj.id.to_s] = b # Store in hash as <class>_<id> string
    end

#   user_build_myco_tree                              # Build the MyCompanyTags tree for this user
#   user_build_belongsto_tree                         # Build the Hosts & Clusters tree for this user
#   user_build_belongsto_tree(true)                   # Build the VMs & Templates tree for this user

    all_roles = MiqUserRole.all
    @edit[:roles] = Hash.new
    @edit[:roles]["<Choose a role>"] = nil
    all_roles.each do | r |
      @edit[:roles][r.name] = r.id
    end
    if @group.miq_user_role == nil              # If adding, set to first role
      @edit[:new][:role] = @edit[:roles][@edit[:roles].keys.sort[0]]
    else
      @edit[:new][:role] = @group.miq_user_role.id
    end

    @edit[:current] = copy_hash(@edit[:new])
    rbac_build_myco_tree                              # Build the MyCompanyTags tree for this user
    build_belongsto_tree(@edit[:new][:belongsto].keys)  # Build the Hosts & Clusters tree for this user
    build_belongsto_tree(@edit[:new][:belongsto].keys, true)  # Build the VMs & Templates tree for this user
  end

  # Build the MyCompany Tags tree
  def rbac_build_myco_tree
    cats = Array.new                            # Array of categories
    categories = Classification.categories.collect {|c| c unless !c.show || ["folder_path_blue", "folder_path_yellow"].include?(c.name)}.compact
    categories.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |category|
      kids_checked = false
      cat_node = Hash.new
      cat_node[:key] = category.name
      cat_node[:title] = category.description
      cat_node[:tooltip] =  "Category: " + category.description
      cat_node[:addClass] = "cfme-no-cursor-node"      # No cursor pointer
      cat_node[:icon] = "folder.png"
      cat_node[:hideCheckbox] = true
      cat_kids = Array.new
      category.entries.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |tag|
        tag_node = Hash.new
        tag_node[:key] = [category.name, tag.name].join("-")
        tag_node[:title] = tag.description
        tag_node[:tooltip] =  "Tag: " + tag.description
        if (@edit && @edit[:new][:filters][tag_node[:key]] == @edit[:current][:filters][tag_node[:key]]) || ![tag_node[:key]].include?(@temp[:filters]) # Check new vs current
          tag_node[:addClass] = "cfme-no-cursor-node"       # No cursor pointer
        else
          tag_node[:addClass] = "cfme-blue-node"            # Show node as different
        end
        tag_node[:icon] = "tag.png"
        tag_node[:select] = true if (@edit && @edit[:new][:filters].has_key?(tag_node[:key])) || (@temp[:filters] && @temp[:filters].has_key?(tag_node[:key])) # Check if tag is assigned
        kids_checked = true if tag_node[:select] == true
        cat_kids.push(tag_node)
      end
      cat_node[:children] = cat_kids unless cat_kids.empty?
      cat_node[:expand] = true if kids_checked
      cats.push(cat_node) unless cat_kids.empty?
    end
    session[:myco_tree] = cats.to_json.html_safe # Add cats node array to root of tree
    session[:tree] = "myco"
  end

  # Set group record variables to new values
  def rbac_group_set_record_vars(group)
    role = MiqUserRole.find_by_id(@edit[:new][:role])
    groups = MiqGroup.all(:order => "sequence DESC")
    group.sequence = groups.first.nil? ? 1 : groups.first.sequence + 1
    group.description = @edit[:new][:description]
    group.miq_user_role = role
    rbac_group_set_filters(group)             # Go set the filters for the group
  end

  # Set filters in the group record from the @edit[:new] hash values
  def rbac_group_set_filters(group)
    @set_filter_values = []
    @edit[:new][:filters].each do | key, value |
      @set_filter_values.push(value)
    end
    rbac_group_make_subarrays # Need to have category arrays of item arrays for and/or logic
    group.set_managed_filters(@set_filter_values)
    group.set_belongsto_filters(@edit[:new][:belongsto].values) # Set belongs to to hash values
  end

  # Need to make arrays by category containing arrays of items so the filtering logic can apply
  # AND between the categories, but OR between the items within a category
  def rbac_group_make_subarrays
    # moved into common method used by ops_settings module as well
    rbac_and_user_make_subarrays
  end

  # Set form variables for role edit
  def rbac_role_set_form_vars
    @edit = Hash.new
    @edit[:role_id] = @record.id if @sb[:typ] != "copy"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "rbac_role_edit__#{@edit[:role_id] || "new"}"

    @edit[:new][:name] = @record.name
    vmr = @record.settings.fetch_path(:restrictions, :vms) if @record.settings
    @edit[:new][:vm_restriction] = vmr || :none
    @edit[:new][:features] = rbac_expand_features(@record.feature_identifiers, MiqProductFeature.feature_root).sort

    @edit[:current] = copy_hash(@edit[:new])

    @role_features = @record.feature_identifiers.sort
    @temp[:features_tree] = rbac_build_features_tree
  end

  # Get array of total set of features from the children of selected features
  def rbac_expand_features(ids, node) # Selected IDS and node to check
    if ids.include?(node)   # This node is selected, return all children
      return [node] + MiqProductFeature.feature_all_children(node)
    else                    # Node is not selected, check this nodes direct children
      nodes = Array.new
      MiqProductFeature.feature_children(node).each do |n|
        nodes += rbac_expand_features(ids, n)
      end
      return nodes
    end
  end

  # Get array of all fully selected parent or leaf node features
  def rbac_compact_features(ids, node)  # Selected IDS and node to check
    return [node] if ids.include?(node) # This feature is selected, return this node
    nodes = Array.new
    MiqProductFeature.feature_children(node).each do |n|
      nodes += rbac_compact_features(ids, n)
    end
    return nodes
  end

  def rbac_role_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:vm_restriction] = params[:vm_restriction].to_sym if params[:vm_restriction]

    # Add/removed features based on the node that was checked
    if params[:check]
      node = params[:id].split("__").last # Get the feature of the checked node
      if params[:check] == "0"  # Unchecked
        if node.starts_with?("_tab_") # Remove all features under this tab
          tab_features = Menu::Manager.tab_features_by_name(node.split("_tab_").last)
          tab_features.each do |f|
            @edit[:new][:features] -= ([f] + MiqProductFeature.feature_all_children(f)) # Remove the feature + children
            rbac_role_remove_parent(f)  # Remove all parents above the unchecked tab feature
          end
        else  # Remove the unchecked feature
          @edit[:new][:features] -= ([node] + MiqProductFeature.feature_all_children(node))
          rbac_role_remove_parent(node) # Remove all parents above the unchecked node
        end
      else                      # Checked
        if node.starts_with?("_tab_") # Add all features under this tab
          tab_features = Menu::Manager.tab_features_by_name(node.split("_tab_").last)
          tab_features.each do |f|
            @edit[:new][:features] += ([f] + MiqProductFeature.feature_all_children(f))
            rbac_role_add_parent(f) # Add any parents above the checked tab feature that have all children checked
          end
        else  # Add the checked feature
          @edit[:new][:features] += ([node] + MiqProductFeature.feature_all_children(node))
          rbac_role_add_parent(node)  # Add any parents above the checked node that have all children checked
        end
      end
    end
    @edit[:new][:features].uniq!
    @edit[:new][:features].sort!
  end

  # Walk the features tree, removing features up to the top
  def rbac_role_remove_parent(node)
    return unless parent = MiqProductFeature.feature_parent(node) # Intentional single =, using parent var below
    @edit[:new][:features] -= [parent]  # Remove the parent from the features array
    rbac_role_remove_parent(parent)   # Remove this nodes parent as well
  end

  # Walk the features tree, adding features up to the top
  def rbac_role_add_parent(node)
    return unless parent = MiqProductFeature.feature_parent(node) # Intentional single =, using parent var below
    if MiqProductFeature.feature_children(parent) - @edit[:new][:features] == []  # All siblings of node are selected
      @edit[:new][:features] += [parent]  # Add the parent to the features array
      rbac_role_add_parent(parent)        # See if this nodes parent needs to be added
    end
  end

  # Set role record variables to new values
  def rbac_role_set_record_vars(role)
    role.name = @edit[:new][:name]
    role.settings ||= Hash.new
    if @edit[:new][:vm_restriction] == :none
      role.settings.delete(:restrictions)
    else
      role.settings[:restrictions] = {:vms=>@edit[:new][:vm_restriction]}
    end
    role.settings = nil if role.settings.empty?
    role.miq_product_features =
      MiqProductFeature.find_all_by_identifier(rbac_compact_features(@edit[:new][:features], MiqProductFeature.feature_root))
  end

  # Validate some of the role fields
  def rbac_role_validate?
    valid = true
    if @edit[:new][:features].empty?
      add_flash(_("At least one %s must be selected") % "Product Feature", :error)
      valid = false
    end
    valid
  end

  # Validate some of the role fields
  def rbac_group_validate?
    valid = true
    if @edit[:new][:filters].empty?
      @assigned_filters = []
    end
    if @edit[:new][:role].nil? || @edit[:new][:role] == ""
      add_flash(_("A User Group must be assigned a Role"), :error)
      valid = false
    end
    valid
  end
end
