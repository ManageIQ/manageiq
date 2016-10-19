class UserValidationService
  def initialize(controller)
    @controller = controller
  end

  extend Forwardable
  delegate [:session, :url_for, :initiate_wait_for_task, :session_init, :clear_current_user,
            :session_reset, :get_vmdb_config, :start_url_for_user] => :@controller

  ValidateResult = Struct.new(:result, :flash_msg, :url)

  # Validate user login credentials
  #   return <url for redirect> as part of the result
  #
  def validate_user(user, task_id = nil, request = nil, authenticate_options = {})
    if task_id.present?
      validation = validate_user_collect_task(user, task_id)
    else # First time thru, kick off authenticate task
      validation = validate_user_kick_off_task(user, request, authenticate_options)
      return validation unless validation.result == :pass
    end

    unless user[:name]
      clear_current_user
      return ValidateResult.new(:fail, @flash_msg ||= _("Error: Authentication failed"))
    end

    if user[:new_password].present?
      begin
        User.find_by_userid(user[:name]).change_password(user[:password], user[:new_password])
      rescue StandardError => bang
        return ValidateResult.new(:fail, "Error: " + bang.message)
      end
    end

    start_url = session[:start_url] # Hang on to the initial start URL
    db_user = User.find_by_userid(user[:name])
    session_reset
    feature = missing_user_features(db_user)
    return ValidateResult.new(
      :fail,
      _("Login not allowed, User's %{feature} is missing. Please contact the administrator") % {:feature => feature}
    ) if feature

    session_init(db_user)

    return validate_user_handle_not_ready(db_user) unless server_ready?

    # Start super admin at the main db if the main db has no records yet
    return validate_user_handle_no_records if db_user.super_admin_user? &&
                                              get_vmdb_config[:product][:maindb] &&
                                              !get_vmdb_config[:product][:maindb].constantize.first

    startpage = start_url_for_user(start_url)
    unless startpage
      return ValidateResult.new(:fail, _("The user's role is not authorized for any access, please contact the administrator!"))
    end
    ValidateResult.new(:pass, nil, startpage)
  end

  def missing_user_features(db_user)
    if !db_user || !db_user.userid
      "User"
    elsif !db_user.current_group
      "Group"
    elsif !db_user.current_group.miq_user_role
      "Role"
    end
  end

  private

  def validate_user_handle_no_records
    ValidateResult.new(:pass, nil, url_for(
                                     :controller    => "ems_infra",
                                     :action        => 'show_list'))
  end

  def validate_user_handle_not_ready(db_user)
    if db_user.super_admin_user?
      ValidateResult.new(:pass, nil, url_for(
                                       :controller    => "ops",
                                       :action        => 'explorer',
                                       :flash_warning => true,
                                       :no_refresh    => true,
                                       :flash_msg     => _("The %{product} Server is still starting, you have been redirected to the diagnostics page for problem determination") % {:product => I18n.t('product.name')},
                                       :escape        => false)
                        )
    else
      ValidateResult.new(:fail, _("The %{product} Server is still starting. If this message persists, please contact your %{product} administrator.") % {:product => I18n.t('product.name')})
    end
  end

  def validate_user_kick_off_task(user, request, authenticate_options = {})
    validate_user_pre_auth_checks(user).tap { |result| return result if result }

    # Call the authentication, use wait_for_task if a task is spawned
    begin
      user_or_taskid = User.authenticate(user[:name], user[:password], request, authenticate_options)
    rescue MiqException::MiqEVMLoginError => err
      user[:name] = nil
      err_message = if err.message.present? && authenticate_options[:require_user]
                      err.message
                    else
                      _("Sorry, the username or password you entered is incorrect.")
                    end
      return ValidateResult.new(:fail, err_message)
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
    return ValidateResult.new(:fail, _("Error: Name is required")) if user.blank? || user[:name].blank?

    return ValidateResult.new(:fail, _("Error: New password and verify password must be the same")) if
      user[:new_password].present? && user[:new_password] != user[:verify_password]

    return ValidateResult.new(:fail, _("Error: New password can not be blank")) if
      user[:new_password] && user[:new_password].blank?

    return ValidateResult.new(:fail, _("Error: New password is the same as existing password")) if
      user[:new_password].present? && user[:password] == user[:new_password]
    nil
  end

  def server_ready?
    MiqServer.my_server(true).logon_status == :ready
  end
end
