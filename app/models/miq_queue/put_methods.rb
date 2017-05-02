module MiqQueuePutMethods

  def put(options)
    options = options.merge(
      :zone         => Zone.determine_queue_zone(options),
      :state        => self::STATE_READY,
      :handler_type => nil,
      :handler_id   => nil,
    )

    create_with_options = all.values[:create_with] || {}
    options[:priority]    ||= create_with_options[:priority] || self::NORMAL_PRIORITY
    options[:queue_name]  ||= create_with_options[:queue_name] || "generic"
    options[:msg_timeout] ||= create_with_options[:msg_timeout] || self::TIMEOUT
    options[:task_id]      = $_miq_worker_current_msg.try(:task_id) unless options.key?(:task_id)
    options[:role]         = options[:role].to_s unless options[:role].nil?

    options[:args] = [options[:args]] if options[:args] && !options[:args].kind_of?(Array)

    if !Rails.env.production? && options[:args] &&
       (arg = options[:args].detect { |a| a.kind_of?(ActiveRecord::Base) && !a.new_record? })
      raise ArgumentError, "MiqQueue.put(:class_name => #{options[:class_name]}, :method => #{options[:method_name]}) does not support args with #{arg.class.name} objects"
    end

    msg = create!(options)
    _log.info(format_full_log_msg(msg))
    msg
  end

  # Find the MiqQueue item with the specified find options, and yields that
  #   record to a block.  The block should return the options for updating
  #   the record.  If the record was not found, the block's options will be
  #   used to put a new item on the queue.
  #
  #   The find options may also contain an optional :args_selector proc that
  #   will allow multiple records found by the find options to further be
  #   searched against the args column, which is normally not easily searchable.
  def put_or_update(find_options)
    find_options  = default_get_options(find_options)
    args_selector = find_options.delete(:args_selector)
    conds = find_options.dup

    # Since args are a serializable field, remove them and manually dump them
    #   for proper comparison.  NOTE: hashes may not compare correctly due to
    #   it's unordered nature.
    where_scope = if conds.key?(:args)
                    args = YAML.dump conds.delete(:args)
                    where(conds).where(['args = ?', args])
                  else
                    where(conds)
                  end

    msg = nil
    loop do
      msg = if args_selector
              where_scope.order("priority, id").detect { |m| args_selector.call(m.args) }
            else
              where_scope.order("priority, id").first
            end

      save_options = block_given? ? yield(msg, find_options) : nil
      unless save_options.nil?
        save_options = save_options.dup
        save_options.delete(:args_selector)
      end

      # Add a new queue item based on the returned save options, or the find
      #   options if no save options were given.
      if msg.nil?
        put_options = save_options || find_options
        put_options.delete(:state)
        msg = put(put_options)
        break
      end

      begin
        # Update the queue item based on the returned save options.
        unless save_options.nil?
          if save_options.key?(:msg_timeout) && (msg.msg_timeout > save_options[:msg_timeout])
            _log.warn("#{format_short_log_msg(msg)} ignoring request to decrease timeout from <#{msg.msg_timeout}> to <#{save_options[:msg_timeout]}>")
            save_options.delete(:msg_timeout)
          end

          msg.update_attributes!(save_options)
          _log.info("#{format_short_log_msg(msg)} updated with following: #{save_options.inspect}")
          _log.info("#{format_full_log_msg(msg)}, Requeued")
        end
        break
      rescue ActiveRecord::StaleObjectError
        _log.debug("#{format_short_log_msg(msg)} stale, retrying...")
      rescue => err
        raise RuntimeError,
              _("%{log_message} \"%{error}\" attempting merge next message") % {:log_message => _log.prefix,
                                                                                :error       => err},
              err.backtrace
      end
    end
    msg
  end

  # Find the MiqQueue item with the specified find options, and if not found
  #   puts a new item on the queue.  If the item was found, it will not be
  #   changed, and will be yielded to an optional block, generally for logging
  #   purposes.
  def put_unless_exists(find_options)
    put_or_update(find_options) do |msg, item_hash|
      ret = yield(msg, item_hash) if block_given?
      # create the record if the original message did not exist, don't change otherwise
      ret if msg.nil?
    end
  end

end
