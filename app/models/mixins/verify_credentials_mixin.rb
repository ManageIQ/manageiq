module VerifyCredentialsMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def validate_credentials_task(args, user_id, zone)
      task_opts = {
        :action => "Validate EMS Provider Credentials",
        :userid => user_id
      }

      queue_opts = {
        :args        => [*args],
        :class_name  => name,
        :method_name => "raw_connect?",
        :queue_name  => "generic",
        :role        => "ems_operations",
        :zone        => zone
      }

      task_id = MiqTask.generic_action_with_callback(task_opts, queue_opts)
      task = MiqTask.wait_for_taskid(task_id, :timeout => 30)

      if task.nil?
        error_message = "Task Error"
      elsif MiqTask.status_error?(task.status) || MiqTask.status_timeout?(task.status)
        error_message = task.message
      end

      [error_message.blank?, error_message]
    end

    def verify_credentials_task(userid, zone, options)
      task_opts = {
        :action => "Verify EMS Provider Credentials",
        :userid => userid
      }

      encrypt_verify_credential_params!(options)

      queue_opts = {
        :args        => [options],
        :class_name  => name,
        :method_name => "verify_credentials?",
        :queue_name  => "generic",
        :role        => "ems_operations",
        :zone        => zone
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def verify_credentials?(args)
      # Prevent the connection details, including the password, from being leaked into the logs
      # and MiqQueue by only returning true/false
      !!verify_credentials(args)
    end

    private

    # Ensure that any passwords are encrypted before putting them onto the queue for any
    # DDF fields which are a password type
    def encrypt_verify_credential_params!(options)
      DDF.traverse(params_for_create) do |field|
        key_path = field[:name].try(:split, '.')
        if options.key_path?(key_path) && field[:type] == 'password'
          options.store_path(key_path, ManageIQ::Password.try_encrypt(options.fetch_path(key_path)))
        end
      end
    end
  end
end
