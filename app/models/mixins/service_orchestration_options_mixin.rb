module ServiceOrchestrationOptionsMixin
  # options to create the stack: read from DB or build from dialog
  def stack_options
    @stack_options ||= get_option(:create_options) || build_stack_create_options
  end

  # override existing stack options (most likely from dialog)
  def stack_options=(opts)
    @stack_options = opts
    save_option(:create_options, opts)
  end

  # options to update the stack: read from DB. Cannot directly read from dialog
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

    proc = ManageIQ::Password.method(encrypt)
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
