module MiqConcurrency
  module PGMutex
    class << self
      require 'zlib'
      require 'securerandom'

      def establish_connection()
        unless ActiveRecord::Base.connected?
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
        end

        @connection = ActiveRecord::Base.connection
      end

      def try_advisory_lock(hashcode)
        establish_connection()
        execute_successful?('pg_try_advisory_lock', hashcode)
      end

      def release_advisory_lock(hashcode)
        establish_connection()
        execute_successful?('pg_advisory_unlock', hashcode)
      end

      def execute_successful?(pg_function, hashcode)
        sql = "SELECT #{pg_function}(#{hashcode}, 0) AS #{unique_column_name()}"
        result = @connection.select_value(sql)
        (result == 't' || result == true)
      end

      def stable_hashcode(input)
        # Postgres requires a 31bit hashcode
        Zlib.crc32(input.to_s) & 0x7fffffff
      end

      def unique_column_name()
        "t#{SecureRandom.hex}"
      end
    end
  end
end
