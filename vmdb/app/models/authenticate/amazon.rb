module Authenticate
  class Amazon < Base
    def __authenticate(username, password, request)
      audit = {:event => "authenticate_amazon", :userid => username}
      if password.blank?
        AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}"))
        return nil
      end

      amazon_auth = AmazonAuth.new
      if amazon_auth.iam_authenticate(username, password)
        AuditEvent.success(audit.merge(:message => "User #{username} successfully validated as Amazon IAM user"))

        if config[:amazon_role] == true
          user = authorize_queue(username)
        else
          # If role_mode == database we will only use amazon for authentication. Also, the user must exist in our database
          # otherwise we will fail authentication
          user = User.find_by_userid(username)
          unless user
            AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
            raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
          end
          return nil unless user
        end

        AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
        user
      else
        AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username}"))
        nil
      end
    end

    def authorize_queue(username)
      task = MiqTask.create(:name => "Amazon IAM User Authorization of '#{username}'", :userid => username)
      unless MiqEnvironment::Process.is_ui_worker_via_command_line?
        cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => cb
        )
      else
        authorize(task.id, username)
      end

      task.id
    end

    def authorize(taskid, username)
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
        # Amazon IAM will be used for authentication and role assignment
        $log.info("#{log_prefix} AWS key: [#{config[:amazon_key]}]")
        amazon_auth = AmazonAuth.new(:auth => config)
        $log.info("#{log_prefix}  User: [#{username}]")
        amazon_user = amazon_auth.iam_user(username)
        $log.debug("#{log_prefix} User obj from Amazon: #{amazon_user.inspect}")
        unless amazon_user
          msg = "Authentication failed for userid #{username}, unable to find IAM user object in Amazon"
          $log.warn("#{log_prefix}: #{msg}")
          AuditEvent.failure(audit.merge(:message => msg))
          task.error(msg)
          task.state_finished
          return nil
        end

        matching_groups = match_groups(amazon_auth.get_memberships(amazon_user))
        user   = User.find_by_userid(username) || User.new(:userid => username)
        user.update_attrs_from_iam(amazon_auth, amazon_user, username)
        user.save_successful_logon(matching_groups, audit, task)
      rescue Exception => err
        $log.log_backtrace(err)
        task.error(err.message)
        AuditEvent.failure(audit.merge(:message => err.message))
        task.state_finished
        raise
      end
    end
  end
end
