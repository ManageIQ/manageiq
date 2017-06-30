require "active_support/core_ext/numeric/time"

module Workers
  class MiqDefaults
    HEARTBEAT_TIMEOUT = 2.minutes.freeze
    STARTING_TIMEOUT  = 10.minutes.freeze
    STOPPING_TIMEOUT  = 10.minutes.freeze

    def self.heartbeat_timeout
      HEARTBEAT_TIMEOUT
    end

    def self.starting_timeout
      STARTING_TIMEOUT
    end

    def self.stopping_timeout
      STOPPING_TIMEOUT
    end
  end
end
