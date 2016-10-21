# Access Control Accordion methods included in OpsController.rb
module OpsController::OpsRbac
  extend ActiveSupport::Concern

  TAG_DB_TO_NAME =  {
                      'MiqGroup'  => 'group',
                      'User'      => 'user',
                      'Tenant'    => 'tenant'
                    }.freeze
  # Edit user or group tags
  def rbac_tags_edit
    case params[:button]
    when "cancel"
      rbac_edit_tags_cancel
    when "save", "add"
      assert_privileges("rbac_#{TAG_DB_TO_NAME[session[:tag_db]]}_tags_edit")
      rbac_edit_tags_save
    when "reset", nil # Reset or first time in
      nodes = x_node.split('-')
      tagging = if nodes.first == "g" || nodes.last == "g"
                  'MiqGroup'
                elsif nodes.first == "u" || nodes.last == "u"
                  'User'
                else
                  params[:tagging]
                end
      rbac_edit_tags_reset(tagging)
    end
  end

  def rbac_user_add
    assert_privileges("rbac_user_add")
    rbac_edit_reset('new', 'user', User)
  end

  def rbac_user_copy
    # get users id either from gtl check or detail id
    user_id = params[:miq_grid_checks].present? ? params[:miq_grid_checks] : params[:id]
    user = User.find(from_cid(user_id))
    # check if it is allowed to copy the user
    if rbac_user_copy_restriction?(user)
      rbac_restricted_user_copy_flash(user)
    end
    if @flash_array
      javascript_flash
      return
    end
    assert_privileges("rbac_user_copy")
    rbac_edit_reset('copy', 'user', User)
  end

  def rbac_user_edit
    assert_privileges("rbac_user_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('user')
    when 'save', 'add' then rbac_edit_save_or_add('user')
    when 'reset', nil  then rbac_edit_reset(params[:typ], 'user', User) # Reset or first time in
    end
  end

  def rbac_group_add
    assert_privileges("rbac_group_add")
    rbac_edit_reset('new', 'group', MiqGroup)
  end

  def rbac_group_edit
    assert_privileges("rbac_group_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('group')
    when 'save', 'add' then rbac_edit_save_or_add('group')
    when 'reset', nil  then rbac_edit_reset(params[:typ], 'group', MiqGroup) # Reset or first time in
    end
  end

  def rbac_role_add
    assert_privileges("rbac_role_add")
    rbac_edit_reset('new', 'role', MiqUserRole)
  end

  def rbac_role_copy
    assert_privileges("rbac_role_copy")
    rbac_edit_reset('copy', 'role', MiqUserRole)
  end

  def rbac_role_edit
    assert_privileges("rbac_role_edit")
    case params[:button]
    when 'cancel'      then rbac_edit_cancel('role')
    when 'save', 'add' then rbac_edit_save_or_add('role', 'miq_user_role')
    when 'reset', nil  then rbac_edit_reset(params[:typ], 'role', MiqUserRole) # Reset or first time in
    end
  end

  def rbac_tenant_add
    assert_privileges("rbac_tenant_add")
    @_params[:typ] = "new"
    @tenant_type = params[:tenant_type] == "tenant"
    rbac_tenant_edit
  end
  alias_method :rbac_project_add, :rbac_tenant_add

  def rbac_tenant_edit
    assert_privileges("rbac_tenant_edit")
    case params[:button]
    when "cancel"
      @tenant = Tenant.find_by_id(params[:id])
      if @tenant.try(:id).nil?
        add_flash(_("Add of new %{model} was cancelled by the user") %
                    {:model => tenant_type_title_string(params[:divisible] == "true")})
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") %
                    {:model => tenant_type_title_string(params[:divisible] == "true"), :name => @tenant.name})
      end
      get_node_info(x_node)
      replace_right_cell(x_node)
    when "save", "add"
      tenant = params[:id] != "new" ? Tenant.find_by_id(params[:id]) : Tenant.new

      # This should be changed to something like tenant.changed? and tenant.changes
      # when we have a version of Rails that supports detecting changes on serialized
      # fields
      old_tenant_attributes = tenant.attributes.clone
      tenant_set_record_vars(tenant)

      begin
        tenant.save!
      rescue => bang
        add_flash(_("Error when adding a new tenant: %{message}") % {:message => bang.message}, :error)
        javascript_flash
      else
        AuditEvent.success(build_saved_audit_hash(old_tenant_attributes, tenant, params[:button] == "add"))
        add_flash(_("%{model} \"%{name}\" was saved") %
                    {:model => tenant_type_title_string(params[:divisible] == "true"), :name => tenant.name})
        if params[:button] == "add"
          rbac_tenants_list
          rbac_get_info
        else
          get_node_info(x_node)
        end
        replace_right_cell("root", [:rbac])
      end
    when "reset", nil # Reset or first time in
      obj = find_checked_items
      obj[0] = params[:id] if obj.blank? && params[:id]
      @tenant = params[:typ] == "new" ? Tenant.new : Tenant.find(obj[0])          # Get existing or new record

      # This is only because ops_controller tries to set form locals, otherwise we should not use the @edit variable
      @edit = {:tenant_id => @tenant.id}

      # This is a hack to trick the controller into thinking we loaded an edit variable
      session[:edit] = {:key => "tenant_edit__#{@tenant.id || 'new'}"}

      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("tenant_edit")
    end
  end

  def tenant_form_fields
    tenant      = Tenant.find_by_id(params[:id])

    render :json => {
      :name                      => tenant.name,
      :description               => tenant.description,
      :default                   => tenant.root?,
      :divisible                 => tenant.divisible,
      :use_config_for_attributes => tenant.use_config_for_attributes
    }
  end

  def tenant_set_record_vars(tenant)
    # there is no params[:name] when use_config_attributes is checked
    tenant.name        = params[:name] if params[:name]
    tenant.description = params[:description]
    tenant.use_config_for_attributes = tenant.root? && (params[:use_config_for_attributes] == "on")
    unless tenant.id # only set for new records
      tenant.parent    = Tenant.find_by_id(from_cid(x_node.split('-').last))
      tenant.divisible = params[:divisible] == "true"
    end
  end

  def rbac_tenant_manage_quotas
    assert_privileges("rbac_tenant_manage_quotas")
    case params[:button]
    when "cancel"
      @tenant = Tenant.find_by_id(params[:id])
      add_flash(_("Manage quotas for %{model}\ \"%{name}\" was cancelled by the user") %
                    {:model => tenant_type_title_string(@tenant.divisible), :name => @tenant.name})
      get_node_info(x_node)
      replace_right_cell(x_node)
    when "save", "add"
      tenant = Tenant.find_by_id(params[:id])
      begin
        if !params[:quotas]
          tenant.set_quotas({})
        else
          tenant_quotas = params[:quotas].deep_symbolize_keys
          tenant.set_quotas(tenant_quotas.to_hash)
        end
      rescue => bang
        add_flash(_("Error when saving tenant quota: %{message}") % {:message => bang.message}, :error)
        javascript_flash
      else
        add_flash(_("Quotas for %{model} \"%{name}\" were saved") %
                      {:model => tenant_type_title_string(tenant.divisible), :name => tenant.name})
        get_node_info(x_node)
        replace_right_cell("root", [:rbac])
      end
    when "reset", nil # Reset or first time in
      obj = find_checked_items
      obj[0] = params[:id] if obj.blank? && params[:id]
      @tenant = Tenant.find(obj[0])          # Get existing or new record
      # This is only because ops_controller tries to set form locals, otherwise we should not use the @edit variable
      @edit = {:tenant_id => @tenant.id}
      session[:edit] = {:key => "tenant_manage_quotas__#{@tenant.id}"}
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("tenant_manage_quotas")
    end
  end

  def tenant_quotas_form_fields
    tenant = Tenant.find_by_id(params[:id])
    tenant_quotas = tenant.get_quotas
    render :json => {
      :name   => tenant.name,
      :quotas => tenant_quotas
    }
  end

  # Edit user or group tags
  def rbac_tenant_tags_edit
    case params[:button]
    when "cancel"
      rbac_edit_tags_cancel
    when "save", "add"
      assert_privileges("rbac_tenant_tags_edit")
      rbac_edit_tags_save
    when "reset", nil # Reset or first time in
      rbac_edit_tags_reset('Tenant')
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
    users = []
    unless params[:id] # showing a list
      ids = find_checked_items.collect { |r| from_cid(r.to_s.split("-").last) }
      users = User.where(:id => ids).compact
      if users.empty?
        add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "User"), :name => "Administrator"}, :error)
        javascript_flash
        return
      else
        restricted_users = []
        users.each do |u|
          user = User.find(u)
          restricted_users.push(user) if rbac_user_delete_restriction?(user)
        end
        # deleting elements in temporary array, had to create temp array to hold id's to be delete, .each gets confused if i deleted them in above loop
        restricted_users.each do |u|
          rbac_restricted_user_delete_flash(u)
          users.delete(u)
        end
      end
      process_users(users, "destroy") unless users.empty?
    else # showing 1 user, delete it
      if params[:id].nil? || User.find_by_id(params[:id]).nil?
        add_flash(_("User no longer exists"), :error)
      else
        user = User.find_by_id(params[:id])
        if rbac_user_delete_restriction?(user)
          rbac_restricted_user_delete_flash(user)
        else
          users.push(params[:id])
        end
      end
      if @flash_array
        javascript_flash
        return
      end
      process_users(users, "destroy") unless users.empty?
      self.x_node  = "xx-u"  # reset node to show list
    end
    get_node_info(x_node)
    replace_right_cell(x_node, [:rbac])
  end

  def rbac_role_delete
    assert_privileges("rbac_role_delete")
    roles = []
    if !params[:id] # showing a role list
      ids = find_checked_items.collect { |r| from_cid(r.to_s.split("-").last) }
      roles = MiqUserRole.where(:id => ids)
      process_roles(roles, "destroy") unless roles.empty?
    else # showing 1 role, delete it
      if params[:id].nil? || MiqUserRole.find_by_id(params[:id]).nil?
        add_flash(_("Role no longer exists"), :error)
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

  def rbac_tenants_list
    rbac_list("tenant")
  end

  def rbac_tenant_delete
    assert_privileges("rbac_tenant_delete")
    tenants = []
    if !params[:id] # showing a tenants list
      tenants = Tenant.where(:id => find_checked_items).reject do |t|
        add_flash(_("Default %{model} \"%{name}\" can not be deleted") % {:model => ui_lookup(:model => "Tenant"),
                                                                          :name  => t.name}, :error) if t.parent.nil?
        t.parent.nil?
      end
    else # showing 1 tenant, delete it
      if params[:id].nil? || Tenant.find_by_id(params[:id]).nil?
        add_flash(_("Tenant no longer exists"), :error)
      else
        tenants.push(params[:id])
      end
      parent_id = Tenant.find_by_id(params[:id]).parent.id
      self.x_node = "tn-#{to_cid(parent_id)}"
    end

    process_tenants(tenants, "destroy") unless tenants.empty?
    get_node_info(x_node)
    replace_right_cell(x_node, [:rbac])
  end

  def rbac_group_delete
    assert_privileges("rbac_group_delete")
    groups = []
    if !params[:id] # showing a list
      ids = find_checked_items.collect { |r| from_cid(r.to_s.split("-").last) }
      groups = MiqGroup.where(:id => ids)
      process_groups(groups, "destroy") unless groups.empty?
      self.x_node  = "xx-g"  # reset node to show list
    else # showing 1 group, delete it
      if params[:id].nil? || MiqGroup.find_by_id(params[:id]).nil?
        add_flash(_("MiqGroup no longer exists"), :error)
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
        group.sequence = i + 1
        if group.save
          AuditEvent.success(build_saved_audit(group, params[:button] == "add"))
        else
          group.errors.each do |field, msg|
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
        drop_breadcrumb(:name => _("Edit User Group Sequence"), :url => "/configuration/ldap_seq_edit")
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
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:new][:ldap_groups] = MiqGroup.non_tenant_groups.sort_by(&:sequence)  #Get the non-tenant groups from the DB
    @edit[:new][:ldap_groups_list] = []
    @edit[:new][:ldap_groups].each do |g|
      @edit[:new][:ldap_groups_list].push(g.description)
    end
    @edit[:key] = "rbac_group_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])

    @right_cell_text = _("Editing Sequence of User Groups")

    session[:edit] = @edit
    session[:changed] = false
  end

  def move_cols_up
    return unless load_edit("rbac_group_edit__seq", "replace_cell__explorer")
    if !params[:seq_fields] || params[:seq_fields].length == 0 || params[:seq_fields][0] == ""
      add_flash(_("No fields were selected to move up"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move up"), :error)
    else
      if first_idx > 0
        @edit[:new][:ldap_groups_list][first_idx..last_idx].reverse_each do |field|
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
      add_flash(_("No fields were selected to move down"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move down"), :error)
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
    @edit[:new][:ldap_groups_list].each_with_index do |nf, idx|
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
    auth = get_vmdb_config[:authentication]
    if @edit[:new][:user].nil? || @edit[:new][:user] == ""
      add_flash(_("User must be entered to perform LDAP Group Look Up"), :error)
    end
    if auth[:mode] != "httpd"
      if @edit[:new][:user_id].nil? || @edit[:new][:user_id] == ""
        add_flash(_("Username must be entered to perform LDAP Group Look Up"), :error)
      end
      if @edit[:new][:user_pwd].nil? || @edit[:new][:user_pwd] == ""
        add_flash(_("User Password must be entered to perform LDAP Group Look Up"), :error)
      end
    end
    if !@flash_array.nil?
      javascript_flash
    else
      @record = MiqGroup.find_by_id(@edit[:group_id])
      @sb[:roles] = @edit[:roles]
      begin
        if auth[:mode] == "httpd"
          @edit[:ldap_groups_by_user] = MiqGroup.get_httpd_groups_by_user(@edit[:new][:user])
        else
          @edit[:ldap_groups_by_user] = MiqGroup.get_ldap_groups_by_user(@edit[:new][:user],
                                                                         @edit[:new][:user_id],
                                                                         @edit[:new][:user_pwd])
        end
      rescue => bang
        @edit[:ldap_groups_by_user] = []
        add_flash(_("Error during 'LDAP Group Look Up': %{message}") % {:message => bang.message}, :error)
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          page.replace("ldap_user_div", :partial => "ldap_auth_users")
        end
      else
        render :update do |page|
          page << javascript_prologue
          page.replace("ldap_user_div", :partial => "ldap_auth_users")
        end
      end
    end
  end

  private ############################

  def tenant_type_title_string(divisible)
    divisible ? ui_lookup(:model => "Tenant") : _("Project")
  end

  # super administrator user with `userid` == "admin" can not be deleted
  # and user can not delete himself
  def rbac_user_delete_restriction?(user)
    ["admin", session[:userid]].include?(user.userid)
  end

  def rbac_user_copy_restriction?(user)
    user.super_admin_user?
  end

  def rbac_restricted_user_delete_flash(user)
    if user.super_admin_user?
      add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "User"), :name => user.name}, :error)
    elsif user.userid == session[:userid]
      add_flash(_("Current %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "User"), :name => user.name}, :error)
    end
  end

  def rbac_restricted_user_copy_flash(user)
    add_flash(_("Default %{model} \"%{name}\" cannot be copied") % {:model => ui_lookup(:model => "User"), :name => user.name}, :error)
  end

  def rbac_edit_tags_reset(tagging)
    @object_ids = find_checked_items
    if params[:button] == "reset"
      id = params[:id] if params[:id]
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
      @object_ids = @edit[:object_ids]
      session[:tag_db] = @tagging = @edit[:tagging]
    else
      @object_ids[0] = params[:id] if @object_ids.blank? && params[:id]
      session[:tag_db] = @tagging = tagging
    end

    @gtl_type = "list"  # No quad icons for user/group list views
    x_tags_set_form_vars
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning)  if params[:button] == "reset"
    @sb[:pre_edit_node] = x_node  unless params[:button]  # Save active tree node before edit
    @right_cell_text = _("Editing %{model} for \"%{name}\"") % {:name => ui_lookup(:models => @tagging), :model => "#{current_tenant.name} Tags"}
    replace_right_cell("root")
  end

  def rbac_edit_tags_cancel
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
    add_flash(_("Tag Edit was cancelled by the user"))
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
    when :tenant
      record_id = id
    end
    add_flash(if record_id
                _("Edit of %{name} was cancelled by the user") % {:name => what.titleize}
              else
                _("Add of new %{name} was cancelled by the user") % {:name => what.titleize}
              end)
    self.x_node  = @sb[:pre_edit_node]
    get_node_info(x_node)
    @edit = nil # clean out the saved info
    replace_right_cell(@nodetype)
  end

  def rbac_edit_reset(operation, what, klass)
    key = what.to_sym
    obj = find_checked_items
    obj[0] = params[:id] if obj.blank? && params[:id]
    record = klass.find_by_id(from_cid(obj[0])) if obj[0]

    if [:group, :role].include?(key) && record && record.read_only && operation != 'copy'
      add_flash(_("Read Only %{model} \"%{name}\" can not be edited") % {:model => key == :role ? ui_lookup(:model => "MiqUserRole") : ui_lookup(:model => "MiqGroup"), :name => key == :role ? record.name : record.description}, :warning)
      javascript_flash
      return
    end
    case operation
    when "new"
      # create new record
      @record = klass.new
      if key == :role
        @record.miq_product_features = [MiqProductFeature.find_by_identifier(MiqProductFeature.feature_root)]
      end
    when "copy"
      # copy existing record
      @record = record.clone
      case key
      when :user
        @record.current_group = record.current_group
      when :group
        @record.miq_user_role = record.miq_user_role
      when :role
        @record.miq_product_features = record.miq_product_features
        @record.read_only = false
      end
    else
      # use existing record
      @record = record
    end
    @sb[:typ] = operation
    # set form fields according to what is copied
    case key
    when :user  then rbac_user_set_form_vars
    when :group then rbac_group_set_form_vars
    when :role  then rbac_role_set_form_vars
    end
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning)  if params[:button] == "reset"
    @sb[:pre_edit_node] = x_node  unless params[:button]  # Save active tree node before edit
    if @edit["#{key}_id".to_sym]
      caption = (key == :group) ? @record.description : @record.name
      @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => caption, :model => what.titleize}
    else
      @right_cell_text = _("Adding a new %{name}") % {:name => what.titleize}
    end
    replace_right_cell(x_node)
  end

  def rbac_edit_save_or_add(what, rbac_suffix = what)
    key         = what.to_sym
    id          = params[:id] || "new"
    add_pressed = params[:button] == "add"

    return unless load_edit("rbac_#{what}_edit__#{id}", "replace_cell__explorer")

    case key
    when :user
      rbac_user_validate?
      rbac_user_set_record_vars(
        record = @edit[:user_id] ? User.find_by_id(@edit[:user_id]) : User.new)
    when :group then
      rbac_group_validate?
      rbac_group_set_record_vars(
        record = @edit[:group_id] ? MiqGroup.find_by_id(@edit[:group_id]) : MiqGroup.new)
    when :role  then
      rbac_role_validate?
      rbac_role_set_record_vars(
        record = @edit[:role_id] ? MiqUserRole.find_by_id(@edit[:role_id]) : MiqUserRole.new)
    end

    if record.valid? && !flash_errors? && record.save
      set_role_features(record) if what == "role"
      AuditEvent.success(build_saved_audit(record, add_pressed))
      subkey = (key == :group) ? :description : :name
      add_flash(_("%{model} \"%{name}\" was saved") % {:model => what.titleize, :name => @edit[:new][subkey]})
      @edit = session[:edit] = nil # clean out the saved info
      if add_pressed
        suffix = case rbac_suffix
                 when "group"         then "g"
                 when "miq_user_role" then "ur"
                 when "user"          then "u"
                 end
        self.x_node = "xx-#{suffix}" # reset node to show list
        send("rbac_#{what.pluralize}_list")
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
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page << javascript_prologue
        page.replace("gtl_div", :partial => "layouts/x_gtl", :locals => {:action_url => "rbac_#{rec_type.pluralize}_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
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
    @sortcol = session["rbac_#{rec_type}_sortcol"].nil? ? 0 : @sb["rbac_#{rec_type}_sortcol"].to_i
    @sortdir = session["rbac_#{rec_type}_sortdir"].nil? ? "ASC" : @sb["rbac_#{rec_type}_sortdir"]

    # Get the records (into a view) and the paginator
    @view, @pages = case rec_type
                    when "user"
                      get_view(User, :named_scope => :in_my_region)
                    when "group"
                      get_view(MiqGroup, :named_scope => :non_tenant_groups)
                    when "role"
                      get_view(MiqUserRole)
                    when "tenant"
                      get_view(Tenant)
                    end

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
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
    bad = false
    if rec_type == "group"
      bad = (@edit[:new][:role].blank? || @edit[:new][:group_tenant].blank?)
    end

    render :update do |page|
      page << javascript_prologue
      if %w(up down).include?(params[:button])
        page.replace("flash_msg_div", :partial => "layouts/flash_msg") unless @refresh_div && @refresh_div != "column_lists"
        page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
        bad = false
      else
        # only do following for groups
        if x_node.split("-").first == "g" || x_node == "xx-g"
          page.replace(@refresh_div,
                       :partial => @refresh_partial,
                       :locals  => {:type => "classifications", :action_url => 'rbac_group_field_changed'}) if @refresh_div

          # Only update description field value if ldap group user field was selected
          page << "$('#description').val('#{j_str(@edit[:new][:description])}');" if params[:ldap_groups_user]

          # don't do anything to lookup box when checkboxes on the right side are checked
          page << set_element_visible('group_lookup', @edit[:new][:lookup]) unless params[:check]
        end
      end
      page << javascript_for_miq_button_visibility(changed && !bad)
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

  def process_tenants(tenants, task)
    process_elements(tenants, Tenant, task, _("Tenant"), "name")
  end

  # Build the main Access Control tree
  def rbac_build_tree
    TreeBuilderOpsRbac.new("rbac_tree", "rbac", @sb)
  end

  # Get information for an access control node
  def rbac_get_info
    node, id = x_node.split("-")
    case node
    when "xx"
      case id
      when "u"
        @right_cell_text = _("Access Control %{model}") % {:model => ui_lookup(:models => "User")}
        rbac_users_list
      when "g"
        @right_cell_text = _("Access Control %{model}") % {:model => ui_lookup(:models => "MiqGroup")}
        rbac_groups_list
      when "ur"
        @right_cell_text = _("Access Control %{model}") % {:model => ui_lookup(:models => "MiqUserRole")}
        rbac_roles_list
      when "tn"
        @right_cell_text = _("Access Control %{model}") % {:model => ui_lookup(:models => "Tenant")}
        rbac_tenants_list
      end
    when "u"
      @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "User"), :name => User.find_by_id(from_cid(id)).name}
      rbac_user_get_details(id)
    when "g"
      @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "MiqGroup"), :name => MiqGroup.find_by_id(from_cid(id)).description}
      rbac_group_get_details(id)
    when "ur"
      @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "MiqUserRole"), :name => MiqUserRole.find_by_id(from_cid(id)).name}
      rbac_role_get_details(id)
    when "tn"
      rbac_tenant_get_details(id)
      @right_cell_text = _("%{model} \"%{name}\"") % {:model => tenant_type_title_string(@tenant.divisible),
                                                      :name  => @tenant.name}
    else  # Root node
      @right_cell_text = _("Access Control %{model} \"%{name}\"") %
                         {:name  => "#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]",
                          :model => ui_lookup(:model => "MiqRegion")}
      @users_count   = Rbac.filtered(User.in_my_region).count
      @groups_count  = Rbac.filtered(MiqGroup.non_tenant_groups).count
      @roles_count   = Rbac.filtered(MiqUserRole).count
      @tenants_count = Rbac.filtered(Tenant).count
    end
  end

  def rbac_user_get_details(id)
    @edit = nil
    @record = @user = User.find_by_id(from_cid(id))
    get_tagdata(@user)
  end

  def rbac_tenant_get_details(id)
    @record = @tenant = Tenant.find_by_id(from_cid(id))
    get_tagdata(@tenant)
  end

  def rbac_group_get_details(id)
    @edit = nil
    @record = @group = MiqGroup.find_by_id(from_cid(id))
    get_tagdata(@group)
    # Build the belongsto filters hash
    @belongsto = {}
    @group.get_belongsto_filters.each do |b|            # Go thru the belongsto tags
      bobj = MiqFilter.belongsto2object(b)            # Convert to an object
      next unless bobj
      @belongsto[bobj.class.to_s + "_" + bobj.id.to_s] = b # Store in hash as <class>_<id> string
    end
    @filters = {}
    # Build the managed filters hash
    [@group.get_managed_filters].flatten.each do |f|
      @filters[f.split("/")[-2] + "-" + f.split("/")[-1]] = f
    end
    @tags_tree = TreeBuilderTags.new(:tags,
                                     :tags_tree,
                                     @sb,
                                     true,
                                     :edit => @edit, :filters => @filters, :group => @group)
    @hac_tree = build_belongsto_tree(@belongsto.keys, false, false)  # Build the Hosts & Clusters tree for this user
    @vat_tree = build_belongsto_tree(@belongsto.keys, true, false)  # Build the VMs & Templates tree for this user
  end

  def rbac_role_get_details(id)
    @edit = nil
    @record = @role = MiqUserRole.find_by_id(from_cid(id))
    @role_features = @role.feature_identifiers.sort
    @features_tree = rbac_build_features_tree
  end

  def rbac_build_features_tree
    @role = @sb[:typ] == "copy" ? @record.dup : @record if @role.nil? # if on edit screen use @record
    TreeBuilder.convert_bs_tree(OpsController::RbacTree.build(@role, @role_features, !@edit.nil?)).to_json
  end

  # Set form variables for role edit
  def rbac_user_set_form_vars
    copy = @sb[:typ] == "copy"
    # save a shadow copy of the record if record is being copied
    @user = copy ? @record.dup : @record
    @edit = {:new => {}, :current => {}}
    @edit[:user_id] = @record.id unless copy
    @edit[:key] = "rbac_user_edit__#{@edit[:user_id] || "new"}"
    # prefill form fields for edit and copy action
    @edit[:new].merge!({
      :name => @user.userid,
      :email => @user.email,
      :group => @user.current_group ? @user.current_group.id : nil,
    })
    unless copy
      @edit[:new].merge!({
        :userid => @user.userid,
        :password => @user.password,
        :verify => @user.password,
      })
    end
    # load all user groups
    @edit[:groups] = MiqGroup.non_tenant_groups.sort_by { |g| g.description.downcase }.collect { |g| [g.description, g.id] }
    # store current state of the new users information
    @edit[:current] = copy_hash(@edit[:new])
  end

  # Get variables from user edit form
  def rbac_user_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:userid] = params[:userid].strip if params[:userid]
    @edit[:new][:email] = params[:email].strip if params[:email]
    @edit[:new][:group] = params[:chosen_group] if params[:chosen_group]

    @edit[:new][:password] = params[:password] if params[:password]
    @edit[:new][:verify] = params[:verify] if params[:verify]
  end

  # Set user record variables to new values
  def rbac_user_set_record_vars(user)
    user.name       = @edit[:new][:name]
    user.userid     = @edit[:new][:userid]
    user.email      = @edit[:new][:email]
    user.miq_groups = [MiqGroup.find_by_id(@edit[:new][:group])].compact
    user.password   = @edit[:new][:password] if @edit[:new][:password]
  end

  # Validate some of the user fields
  def rbac_user_validate?
    valid = true
    if @edit[:new][:password] != @edit[:new][:verify]
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
      @edit[:new][:ldap_groups_user] = params[:ldap_groups_user]  if params[:ldap_groups_user]
      @edit[:new][:description]      = params[:description]       if params[:description]
      @edit[:new][:role]             = params[:group_role]        if params[:group_role]
      @edit[:new][:group_tenant]     = params[:group_tenant].to_i if params[:group_tenant]
      @edit[:new][:lookup]           = (params[:lookup] == "1")   if params[:lookup]
      @edit[:new][:user]             = params[:user]              if params[:user]
      @edit[:new][:user_id]          = params[:user_id]           if params[:user_id]
      @edit[:new][:user_pwd]         = params[:password]          if params[:password]
    end

    if params[:check]                               # User checked/unchecked a tree node
      if params[:tree_typ] == "tags"                # MyCompany tag checked
        cat, tag = params[:id].split('cl-').last.split("_xx-") # Get the category and tag
        cat_name = Classification.find_by(:id => from_cid(cat)).name
        tag_name = Classification.find_by(:id => tag).name
        if params[:check] == "0"                    #   unchecked
          @edit[:new][:filters].except!("#{cat_name}-#{tag_name}") # Remove the tag from the filters array
        else                                        #   checked
          @edit[:new][:filters]["#{cat_name}-#{tag_name}"] = "/managed/#{cat_name}/#{tag_name}" # Put them in the hash
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
    @assigned_filters = []
    @group = @record
    @edit = {
      :new => {
        :filters => {},
        :belongsto => {},
        :description => @group.description,
      },
      :ldap_groups_by_user => [],
      :projects_tenants => [],
      :roles => {},
    }
    @edit[:group_id] = @record.id
    @edit[:key] = "rbac_group_edit__#{@edit[:group_id] || "new"}"

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

    # Build roles hash
    @edit[:roles]["<Choose a Role>"] = nil if @record.id.nil?
    MiqUserRole.all.each do |r|
      @edit[:roles][r.name] = r.id
    end
    if @group.miq_user_role.nil? # If adding, set to first role
      @edit[:new][:role] = @edit[:roles][@edit[:roles].keys.sort[0]]
    else
      @edit[:new][:role] = @group.miq_user_role.id
    end

    all_tenants, all_projects = Tenant.tenant_and_project_names
    @edit[:projects_tenants].push(["", [[_("<Choose a Project/Tenant>"),
                                         :selected => _("<Choose a Project/Tenant>"),
                                         :disabled => _("<Choose a Project/Tenant>"),
                                         :style    => 'display:none']]])
    @edit[:projects_tenants].push(["Projects", all_projects]) unless all_projects.blank?
    @edit[:projects_tenants].push(["Tenants", all_tenants]) unless all_tenants.blank?
    @edit[:new][:group_tenant] = @group.tenant_id

    @edit[:current] = copy_hash(@edit[:new])
    @tags_tree = TreeBuilderTags.new(:tags,
                                     :tags_tree,
                                     @sb,
                                     true,
                                     :edit => @edit, :filters => @filters, :group => @group)
    @hac_tree = build_belongsto_tree(@edit[:new][:belongsto].keys, false, false)  # Build the Hosts & Clusters tree for this user
    @vat_tree = build_belongsto_tree(@edit[:new][:belongsto].keys, true, false)  # Build the VMs & Templates tree for this user
  end

  # Set group record variables to new values
  def rbac_group_set_record_vars(group)
    role = MiqUserRole.find_by_id(@edit[:new][:role])
    group.description = @edit[:new][:description]
    group.miq_user_role = role
    group.tenant = Tenant.find_by_id(@edit[:new][:group_tenant]) if @edit[:new][:group_tenant]
    rbac_group_set_filters(group)             # Go set the filters for the group
  end

  # Set filters in the group record from the @edit[:new] hash values
  def rbac_group_set_filters(group)
    @set_filter_values = []
    @edit[:new][:filters].each do |_key, value|
      @set_filter_values.push(value)
    end
    rbac_group_make_subarrays # Need to have category arrays of item arrays for and/or logic
    group.entitlement ||= Entitlement.new
    group.entitlement.set_managed_filters(@set_filter_values)
    group.entitlement.set_belongsto_filters(@edit[:new][:belongsto].values) # Set belongs to to hash values
  end

  # Need to make arrays by category containing arrays of items so the filtering logic can apply
  # AND between the categories, but OR between the items within a category
  def rbac_group_make_subarrays
    # moved into common method used by ops_settings module as well
    rbac_and_user_make_subarrays
  end

  # Set form variables for role edit
  def rbac_role_set_form_vars
    @edit = {}
    @edit[:role_id] = @record.id if @sb[:typ] != "copy"
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:key] = "rbac_role_edit__#{@edit[:role_id] || "new"}"

    @edit[:new][:name] = @record.name
    vmr = @record.settings.fetch_path(:restrictions, :vms) if @record.settings
    @edit[:new][:vm_restriction] = vmr || :none
    @edit[:new][:features] = rbac_expand_features(@record.feature_identifiers).sort

    @edit[:current] = copy_hash(@edit[:new])

    @role_features = @record.feature_identifiers.sort
    @features_tree = rbac_build_features_tree
  end

  # Get array of total set of features from the children of selected features
  def rbac_expand_features(selected, node = nil)
    node ||= MiqProductFeature.feature_root
    if selected.include?(node)
      [node] + MiqProductFeature.feature_all_children(node)
    else
      MiqProductFeature.feature_children(node).flat_map { |n| rbac_expand_features(selected, n) }
    end
  end

  # Get array of all fully selected parent or leaf node features
  def rbac_compact_features(selected, node = nil)
    node ||= MiqProductFeature.feature_root
    return [node] if selected.include?(node)
    MiqProductFeature.feature_children(node, false).flat_map do |n|
      rbac_compact_features(selected, n)
    end
  end

  # Yield all features for given tree node a section or feature
  #
  # a. special case _tab_all_vm_rules
  # b. section node /^_tab_/
  #   return all features below this section and
  #   recursively below any nested sections
  #   and nested features recursively
  # c. feature node
  #   return nested features recursively
  #
  def recurse_sections_and_features(node)
    if node =~ /_tab_all_vm_rules$/
      MiqProductFeature.feature_children('all_vm_rules').each do |feature|
        kids = MiqProductFeature.feature_all_children(feature)
        yield feature, [feature] + kids
      end
    elsif node =~ /^_tab_/
      section_id = node.split('_tab_').last.to_sym
      Menu::Manager.section(section_id).features_recursive.each do |f|
        kids = MiqProductFeature.feature_all_children(f)
        yield f, [f] + kids
      end
    else
      kids = MiqProductFeature.feature_all_children(node)
      yield node, [node] + kids
    end
  end

  def rbac_role_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:vm_restriction] = params[:vm_restriction].to_sym if params[:vm_restriction]

    # Add/removed features based on the node that was checked
    if params[:check]
      node = params[:id].split("__").last # Get the feature of the checked node
      if params[:check] == "0"  # Unchecked
        recurse_sections_and_features(node) do |feature, all|
          @edit[:new][:features] -= all # remove the feature + children
          rbac_role_remove_parent(feature) # remove all parents above the unchecked tab feature
        end
      else                      # Checked
        recurse_sections_and_features(node) do |feature, all|
          @edit[:new][:features] += all # remove the feature + children
          rbac_role_add_parent(feature) # remove all parents above the unchecked tab feature
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
    return unless (parent = MiqProductFeature.feature_parent(node)) # Intentional single =, using parent var below
    if MiqProductFeature.feature_children(parent, false) - @edit[:new][:features] == []  # All siblings of node are selected
      @edit[:new][:features] += [parent]  # Add the parent to the features array
      rbac_role_add_parent(parent)        # See if this nodes parent needs to be added
    end
  end

  # Set role record variables to new values
  def rbac_role_set_record_vars(role)
    role.name = @edit[:new][:name]
    role.settings ||= {}
    if @edit[:new][:vm_restriction] == :none
      role.settings.delete(:restrictions)
    else
      role.settings[:restrictions] = {:vms => @edit[:new][:vm_restriction]}
    end
    role.settings = nil if role.settings.empty?
  end

  def set_role_features(role)
    role.miq_product_features =
      MiqProductFeature.find_all_by_identifier(rbac_compact_features(@edit[:new][:features]))
  end

  # Validate some of the role fields
  def rbac_role_validate?
    valid = true
    if @edit[:new][:features].empty?
      add_flash(_("At least one Product Feature must be selected"), :error)
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
