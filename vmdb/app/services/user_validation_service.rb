class UserValidationService
  def initialize(controller)
    @controller = controller
  end

  extend Forwardable
  delegate [:session, :url_for, :initiate_wait_for_task, :session_init,
            :session_reset, :get_vmdb_config, :start_url_for_user] => :@controller

  ValidateResult = Struct.new(:result, :flash_msg, :url)

  # Validate user login credentials
  #   return <url for redirect> as part of the result
  #
  def validate_user(user, task_id = nil, request = nil)
    if task_id.present?
      validation = validate_user_collect_task(user, task_id)
    else # First time thru, kick off authenticate task
      validation = validate_user_kick_off_task(user, request)
      return validation unless validation.result == :pass
    end

    unless user[:name]
      session[:userid], session[:username], session[:user_tags] = nil
      User.current_userid = nil
      return ValidateResult.new(:fail, @flash_msg ||= "Error: Authentication failed")
    end

    if user[:new_password].present?
      begin
        User.find_by_userid(user[:name]).change_password(user[:password], user[:new_password])
      rescue StandardError => bang
        return ValidateResult.new(:fail, "Error: " + bang.message)
      end
    end

    db_user = User.find_by_userid(user[:name])
    return ValidateResult.new(
      :fail,
      _("Login not allowed, User's %s is missing. Please contact the administrator") %
      (session[:group] ? "Role" : "Group")
    ) unless session_reset(db_user) # Reset/recreate the session hash

    start_url = session[:start_url] # Hang on to the initial start URL

    # Don't allow logins until there's some content in the system
    return ValidateResult.new(
      :fail,
      "Logins not allowed, no providers are being managed yet. Please contact the administrator"
    ) unless user_is_super_admin? || Vm.first || Host.first

    session_init(db_user) # Initialize the session hash variables

    return validate_user_handle_not_ready if MiqServer.my_server(true).logon_status != :ready

    # Start super admin at the main db if the main db has no records yet
    return validate_user_handle_no_records if user_is_super_admin? &&
                                                get_vmdb_config[:product][:maindb] &&
                                                  !get_vmdb_config[:product][:maindb].constantize.first

    ValidateResult.new(:pass, nil, start_url_for_user(start_url))
  end

  private

  def validate_user_handle_no_records
    ValidateResult.new(:pass, nil, url_for(
      :controller    => "ems_infra",
      :action        => 'show_list',
      :flash_warning => true,
      :flash_msg     => _("Non-admin users can not access the system until at least 1 VM/Instance has been discovered"))
    )
  end

  def user_is_super_admin?
    session[:userrole] == 'super_administrator'
  end

  def validate_user_handle_not_ready
    if user_is_super_admin?
      ValidateResult.new(:pass, nil, url_for(
        :controller    => "ops",
        :action        => 'explorer',
        :flash_warning => true,
        :no_refresh    => true,
        :flash_msg     => _("The CFME Server is still starting, you have been redirected to the diagnostics page for problem determination"),
        :escape        => false)
      )
    else
      ValidateResult.new(:fail, _("The CFME Server is still starting. If this message persists, please contact your CFME administrator."))
    end
  end

  def validate_user_kick_off_task(user, request)
    validate_user_pre_auth_checks(user).tap { |result| return result if result }

    # Call the authentication, use wait_for_task if a task is spawned
    begin
      user_or_taskid = User.authenticate(user[:name], user[:password], request)
    rescue MiqException::MiqEVMLoginError
      user[:name] = nil
      return ValidateResult.new(:fail, _("Sorry, the username or password you entered is incorrect."))
    end

    if user_or_taskid.kind_of?(User)
      user[:name] = user_or_taskid.userid
      return ValidateResult.new(:pass)
    else
      initiate_wait_for_task(:task_id => user_or_taskid)
      return ValidateResult.new(:wait_for_task, nil)
    end
  end

  def validate_user_collect_task(user, task_id)
    task = MiqTask.find_by_id(task_id)
    if task.status.downcase != "ok"
      validate = ValidateResult.new(:fail, "Error: " + task.message)
      task.destroy
      return validate
    end
    user[:name] = task.userid
    task.destroy
    ValidateResult.new(:pass)
  end

  def validate_user_pre_auth_checks(user)
    # Pre_authenticate checks
    return ValidateResult.new(:fail, "Error: Name is required") if user.blank? || user[:name].blank?

    return ValidateResult.new(:fail, "Error: New password and verify password must be the same") if
      user[:new_password].present? && user[:new_password] != user[:verify_password]

    return ValidateResult.new(:fail, "Error: New password can not be blank") if user[:new_password] == ''

    return ValidateResult.new(:fail, "Error: New password is the same as existing password") if
      user[:new_password].present? && user[:password] == user[:new_password]
    nil
  end
end
