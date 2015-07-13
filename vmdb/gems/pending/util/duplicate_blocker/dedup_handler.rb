module DuplicateBlocker
  class DedupHandler
    #
    # The number of duplicates in a preset time window needed to trip the breaker.
    #
    attr_accessor :duplicate_threshold

    #
    # The time window in seconds
    #
    attr_accessor :duplicate_window

    #
    # The width of a slot in seconds. The time window is divided into many slots.
    #
    attr_accessor :window_slot_width

    #
    # Report the total number of blocked calls for every this many duplicates
    #
    attr_accessor :progress_threshold

    #
    # Flag whether throw an exception when a call is blocked due to too duplications
    #
    attr_accessor :throw_exception_when_blocked

    #
    # A hash history of duplicates. The value is also a hash with the following keys
    #   :description
    #   :dup_count
    #   :blocked_count
    #   :slots => [{:timestamp, :count}]
    #   :last_updated
    #
    attr_reader :histories

    #
    # Optional logger.
    #
    attr_accessor :logger

    DEFAULT_DUPLICATE_THRESHOLD = 120
    DEFAULT_DUPLICATE_WINDOW    = 60
    DEFAULT_SLOT_WIDTH          = 0.1
    DEFAULT_PROGRESS_THRESHOLD  = 500
    DEFAULT_THROW_EXECEPTION    = true

    def initialize(logger = nil)
      @logger = logger
      @duplicate_threshold          = DEFAULT_DUPLICATE_THRESHOLD
      @duplicate_window             = DEFAULT_DUPLICATE_WINDOW
      @window_slot_width            = DEFAULT_SLOT_WIDTH
      @progress_threshold           = DEFAULT_PROGRESS_THRESHOLD
      @throw_exception_when_blocked = DEFAULT_THROW_EXECEPTION
      @histories = {}
    end

    #
    # Handles the method covered by the duplicate blocker.
    #
    def handle(method, *args)
      key = key_generator.call(method, *args)
      desc = descriptor.call(method, *args)

      entry = update_history(key, desc)
      tripped?(entry) ? on_blocking_call(desc) : method[*args]
    end

    def default_key_generator(meth, *args)
      [meth, *args]
    end

    def key_generator
      @key_generator ||= method(:default_key_generator)
    end

    #
    # Allow the user to provide a proc to generate a key based on the method and parameters
    # The generator proc will receive argument (meth, *args)
    #
    attr_writer :key_generator

    def default_descriptor(meth, *args)
      "#{meth.owner.name}.#{meth.name} with arguments #{args}"
    end

    def descriptor
      @descriptor ||= method(:default_descriptor)
    end

    #
    # Allow the user to provide a proc to generate a description based on the method and parameters
    # The descriptor proc will receive argument (meth, *args)
    #
    attr_writer :descriptor

    #
    # Remove outdated histories from the hash. This is a maintenance call, meant to be used by a
    # scheduler less frequently.
    #
    def purge_histories
      now = Time.now
      histories.delete_if { |_key, value| now - value[:last_updated] >= duplicate_window }
    end

    TimeSlot = Struct.new(:timestamp, :count)

    class History < Struct.new(:handler, :description, :dup_count, :blocked_count, :slots, :last_updated)
      # return total count change in slots (not including the current slot)
      def update_slots(now)
        slot_width = handler.window_slot_width
        last_timestamp = slots[-1][:timestamp]
        if now - last_timestamp < slot_width
          slots[-1][:count] += 1
          0
        else
          timestamp = last_timestamp + ((now - last_timestamp) / slot_width).to_int * slot_width
          count_change = 0
          # drop slots (from head) that are outdated
          slots.drop_while do |s|
            if timestamp - s[:timestamp] > handler.duplicate_window
              count_change -= s[:count]
              true
            end
          end
          # seal the tail slot and append a new one
          count_change += slots[-1][:count]
          slots << TimeSlot.new(timestamp, 1)
          self.dup_count += count_change
        end
      end
    end

    private

    def tripped?(entry)
      if entry[:dup_count] >= duplicate_threshold
        if entry[:blocked_count] == 0
          trip(entry)
        else
          entry[:blocked_count] += 1
          report_tripping_still_on(entry) if entry[:blocked_count] % progress_threshold == 0
        end
        true
      else
        reset(entry) if entry[:blocked_count] > 0
        false
      end
    end

    # state from normal to tripped
    def trip(entry)
      @logger.warn("Breaker for #{entry[:description]} is tripped. " \
        "Further calls are blocked.") if @logger
      # other notification can be added here

      entry[:blocked_count] = 1
    end

    # state from tripped to normal
    def reset(entry)
      @logger.info("Tripped condition for #{entry[:description]} is now reset. " \
        "Total #{entry[:blocked_count]} calls were blocked.") if @logger
      # other notification can be added here

      entry[:blocked_count] = 0
    end

    def report_tripping_still_on(entry)
      @logger.warn("Breaker for #{entry[:description]} is still tripped. " \
        "Total #{entry[:blocked_count]} calls have been blocked.") if @logger
      # other notification can be added here
    end

    def update_history(key, desc)
      now = Time.now
      history = histories[key]
      if history.nil?
        history = History.new(self, desc, 0, 0, [TimeSlot.new(now, 1)])
        histories[key] = history
      else
        history.update_slots now
      end
      history[:last_updated] = now
      history
    end

    #
    # Called when a call is blocked. Raises a DuplicateFoundException exception if necessary.
    #
    def on_blocking_call(msg)
      @logger.debug("#{msg} is blocked because it is duplicated.") if @logger

      raise(DuplicateFoundException, msg, caller) if throw_exception_when_blocked
    end
  end
end
