require 'yaml'
require 'miq-password'

# FIXME:  NEEDS MAJOR REFACTORING
#
# We should be sharing methods from app/models/miq_queue.rb, but copy-pasta for
# now for POC.  Fix before MERGE
module Mini
  # class SettingsChange < ActiveRecord::Base
  # end

  class MiqQueue < ActiveRecord::Base
    NORMAL_PRIORITY = 100
    TIMEOUT = 10.minutes
    STATE_READY   = 'ready'.freeze
    DEFAULT_QUEUE  = "generic"

    self.table_name = "miq_queue"

    def data
      msg_data && Marshal.load(msg_data)
    end

    def data=(value)
      self.msg_data = Marshal.dump(value)
    end

    def self.put(options)
      options = options.merge(
        :zone         => Zone.determine_queue_zone(options),
        :state        => STATE_READY,
        :handler_type => nil,
        :handler_id   => nil,
      )

      create_with_options = all.values[:create_with] || {}
      options[:priority]    ||= create_with_options[:priority] || NORMAL_PRIORITY
      options[:queue_name]  ||= create_with_options[:queue_name] || "generic"
      options[:msg_timeout] ||= create_with_options[:msg_timeout] || TIMEOUT
      options[:task_id]      = $_miq_worker_current_msg.try(:task_id) unless options.key?(:task_id)
      options[:role]         = options[:role].to_s unless options[:role].nil?

      options[:args] = [options[:args]] if options[:args] && !options[:args].kind_of?(Array)

      if !(ENV["RAILS_ENV"] == "production") && options[:args] &&
         (arg = options[:args].detect { |a| a.kind_of?(ActiveRecord::Base) && !a.new_record? })
        raise ArgumentError, "MiqQueue.put(:class_name => #{options[:class_name]}, :method => #{options[:method_name]}) does not support args with #{arg.class.name} objects"
      end

      msg = MiqQueue.create!(options)
      _log.info(MiqQueue.format_full_log_msg(msg))
      msg
    end

    def self.put_or_update(find_options)
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
              _log.warn("#{MiqQueue.format_short_log_msg(msg)} ignoring request to decrease timeout from <#{msg.msg_timeout}> to <#{save_options[:msg_timeout]}>")
              save_options.delete(:msg_timeout)
            end

            msg.update_attributes!(save_options)
            _log.info("#{MiqQueue.format_short_log_msg(msg)} updated with following: #{save_options.inspect}")
            _log.info("#{MiqQueue.format_full_log_msg(msg)}, Requeued")
          end
          break
        rescue ActiveRecord::StaleObjectError
          _log.debug("#{MiqQueue.format_short_log_msg(msg)} stale, retrying...")
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
    def self.put_unless_exists(find_options)
      put_or_update(find_options) do |msg, item_hash|
        ret = yield(msg, item_hash) if block_given?
        # create the record if the original message did not exist, don't change otherwise
        ret if msg.nil?
      end
    end

    def self.format_full_log_msg(msg)
      "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{MiqPassword.sanitize_string(msg.args.inspect)}"
    end

    def self.format_short_log_msg(msg)
      "Message id: [#{msg.id}]"
    end

    private

    # default values for get operations
    def self.default_get_options(options)
      options.reverse_merge(
        :queue_name => DEFAULT_QUEUE,
        :state      => STATE_READY,
        :zone       => Zone.determine_queue_zone(options)
      )
    end

  end

  # class MiqRegion < ActiveRecord::Base
  #   def self.my_region(use_cache=false)
  #     find_by(:region => discover_my_region_number)
  #   end

  #   def self.id_to_region(id)
  #     id.to_i / 1_000_000_000_000
  #   end

  #   def self.region_number_from_sequence
  #     return unless connection.data_source_exists?("miq_databases")
  #     id_to_region(connection.select_value("SELECT last_value FROM miq_databases_id_seq"))
  #   end

  #   def self.discover_my_region_number
  #     # region_file = File.join(Rails.root, "REGION")
  #     # region_num = File.read(region_file) if File.exist?(region_file)
  #     region_num ||= ENV.fetch("REGION", nil)
  #     region_num ||= region_number_from_sequence
  #     region_num.to_i
  #   end
  # end

  # class MiqServer < ActiveRecord::Base
  #   def miq_region
  #     MiqRegion.my_region
  #   end
  # end

  # class MiqServer < ActiveRecord::Base
  #   def miq_region
  #     MiqRegion.my_region
  #   end
  # end

  class Zone < ActiveRecord::Base
    # Simplified form of app/models/zone.rb:86 since we never do the lookup and
    # always pass in the options[:zone]
    def self.determine_queue_zone(options)
      options[:zone] # return specified zone including nil (aka ANY zone)
    end
  end
end

# FIXME: HACK
# SettingsChange = Mini::SettingsChange
# MiqServer = Mini::MiqServer
