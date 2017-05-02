module MiqQueueConstants
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  MAX_PRIORITY    = 0
  HIGH_PRIORITY   = 20
  NORMAL_PRIORITY = 100
  LOW_PRIORITY    = 150
  MIN_PRIORITY    = 200

  PRIORITY_WHICH  = [:max, :high, :normal, :low, :min]
  PRIORITY_DIR    = [:higher, :lower]

  STATE_READY     = 'ready'.freeze
  STATE_DEQUEUE   = 'dequeue'.freeze
  STATE_WARN      = 'warn'.freeze
  STATE_ERROR     = 'error'.freeze
  STATE_TIMEOUT   = 'timeout'.freeze
  STATE_EXPIRED   = "expired".freeze

  FINISHED_STATES = [STATE_WARN, STATE_ERROR, STATE_TIMEOUT, STATE_EXPIRED].freeze

  STATUS_OK       = 'ok'.freeze
  STATUS_RETRY    = 'retry'.freeze
  STATUS_WARN     = STATE_WARN
  STATUS_ERROR    = STATE_ERROR
  STATUS_TIMEOUT  = STATE_TIMEOUT
  STATUS_EXPIRED  = STATE_EXPIRED

  TIMEOUT         = 10.minutes
  DEFAULT_QUEUE   = "generic"

  module ClassMethods
    # default values for get operations
    def default_get_options(options)
      options.reverse_merge(
        :queue_name => DEFAULT_QUEUE,
        :state      => STATE_READY,
        :zone       => Zone.determine_queue_zone(options)
      )
    end
    private :default_get_options
  end
end
