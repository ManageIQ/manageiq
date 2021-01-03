module AnsiblePlaybookMixin
  extend ActiveSupport::Concern

  CONFIG_OPTIONS_WHITELIST = %i[
    become_enabled
    cloud_credential_id
    credential_id
    execution_ttl
    extra_vars
    hosts
    network_credential_id
    vault_credential_id
    verbosity
  ].freeze

  def translate_credentials!(options)
    %i[credential vault_credential network_credential cloud_credential].each do |cred|
      cred_sym = "#{cred}_id".to_sym
      credential_id = options.delete(cred_sym)
      options[cred] = Authentication.find(credential_id).native_ref if credential_id.present?
    end
  end

  def use_default_inventory?(hosts)
    hosts.blank? || hosts == 'localhost'
  end

  def hosts_array(hosts_string)
    return ["localhost"] if use_default_inventory?(hosts_string)

    hosts_string.split(',').map(&:strip).delete_blanks
  end

  def playbook_log_stdout(log_option, job)
    raise ArgumentError, "invalid job object" if job.nil?
    return unless %(on_error always).include?(log_option)
    return if log_option == 'on_error' && job.raw_status.succeeded?

    $log.info("Stdout from ansible job #{job.name}: #{job.raw_stdout('txt_download')}")
  rescue StandardError => err
    if job.nil?
      $log.error("Job was nil, must pass a valid job")
    else
      $log.error("Failed to get stdout from ansible job #{job.name}")
    end
    $log.log_backtrace(err)
  end
end
