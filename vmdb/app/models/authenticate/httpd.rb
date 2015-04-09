module Authenticate
  class Httpd < Base
    def __authenticate(username, password, request)
      audit = {:event => "authenticate_httpd", :userid => username}
      if request.nil?
        AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}, request missing"))
        nil
      elsif request.headers['X_REMOTE_USER'].present?
        AuditEvent.success(audit.merge(:message => "User #{username} successfully validated by httpd"))

        if config[:httpd_role] == true
          user = authorize_queue(username, request)
        else
          # If role_mode == database we will only use httpd for authentication. Also, the user must exist in our database
          # otherwise we will fail authentication
          unless (user = User.find_by_userid(username))
            AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
            raise MiqException::MiqEVMLoginError,
                  "User authenticated but not defined in EVM, please contact your EVM administrator"
          end
        end

        AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
        user
      else
        external_auth_error = request.headers['HTTP_X_EXTERNAL_AUTH_ERROR']
        AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username} #{external_auth_error}"))
        nil
      end
    end

    def authorize_queue(username, request)
      task = MiqTask.create(:name => "External httpd User Authorization of '#{username}'", :userid => username)
      user_attrs = {:username  => username,
                    :fullname  => request.headers['X_REMOTE_USER_FULLNAME'],
                    :firstname => request.headers['X_REMOTE_USER_FIRSTNAME'],
                    :lastname  => request.headers['X_REMOTE_USER_LASTNAME'],
                    :email     => request.headers['X_REMOTE_USER_EMAIL']}
      membership_list = (request.headers['X_REMOTE_USER_GROUPS'] || '').split(":")

      if !MiqEnvironment::Process.is_ui_worker_via_command_line?
        authorize(task.id, username, user_attrs, membership_list)
      else
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username, user_attrs, membership_list],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => {
            :class_name  => task.class.name,
            :instance_id => task.id,
            :method_name => :queue_callback_on_exceptions,
            :args        => ['Finished']
          })
      end

      task.id
    end

    def authorize(taskid, username, user_attrs, membership_list)
      log_prefix = "MIQ(User.authorize):"
      audit = {:event => "authorize", :userid => username}

      task = MiqTask.find_by_id(taskid)
      if task.nil?
        message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
        $log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", "Authorizing")

      begin
        $log.info("#{log_prefix}  User: [#{username}]")

        matching_groups = match_groups(membership_list)
        user = User.find_by_userid(username) || User.new(:userid => username)
        user.update_attrs_from_httpd(user_attrs)
        user.save_successful_logon(matching_groups, audit, task)
      rescue => err
        $log.log_backtrace(err)
        task.error(err.message)
        AuditEvent.failure(audit.merge(:message => err.message))
        task.state_finished
        raise
      end
    end
  end
end
