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

    def self.heartbeat_file(guid = nil)
      guid ||= "miq_worker"
      ENV["WORKER_HEARTBEAT_FILE"] || File.expand_path("../../../tmp/#{guid}.hb", __FILE__)
    end
  end
end
