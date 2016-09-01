module ServiceLoadBalancerOptionsMixin
  # options to create the load_balancer: read from DB or build from dialog
  def load_balancer_options
    @load_balancer_options ||= get_option(:create_options) || build_load_balancer_options_from_dialog(get_option(:dialog))
  end

  # override existing load_balancer options (most likely from dialog)
  def load_balancer_options=(opts)
    @load_balancer_options = opts
    save_option(:create_options, opts)
  end

  # options to update the load_balancer: read from DB. Cannot directly read from dialog
  def update_options
    @update_options ||= get_option(:update_options)
  end

  # must explicitly call this to set the options for update since they cannot be directly read from dialog
  def update_options=(opts)
    @update_options = opts
    save_option(:update_options, opts)
  end

  private

  def dup_and_process_password(opts, encrypt = :encrypt)
    return opts unless opts.kind_of?(Hash)

    opts_dump = opts.deep_dup

    proc = MiqPassword.method(encrypt)
    opts_dump.each do |_opt_name, opt_val|
      next unless opt_val.kind_of?(Hash)
      opt_val.each { |param_key, param_val| opt_val[param_key] = proc.call(param_val) if param_key =~ /password/i }
    end

    opts_dump
  end

  def get_option(option_name)
    dup_and_process_password(options[option_name], :decrypt) if options[option_name]
  end

  def save_option(option_name, val)
    options[option_name] = dup_and_process_password(val, :encrypt)
    save!
  end
end
