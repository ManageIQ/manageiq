module MiqConcurrency
  module PGMutex
    class << self
      require 'zlib'
      require 'securerandom'

      def try_advisory_lock(lock_name)
        execute_successful?('pg_try_advisory_lock', lock_name)
      end

      def release_advisory_lock(lock_name)
        execute_successful?('pg_advisory_unlock', lock_name)
      end

      def count_advisory_lock(lock_name)
        establish_connection
        hashcode = stable_hashcode(lock_name)
        sql = "SELECT count(*) from pg_locks "\
              "WHERE locktype = 'advisory' "\
              "AND objid = #{hashcode} "\
              "AND pid = pg_backend_pid()"
        @connection.select_value(sql).to_i
      end

      private

      def establish_connection
        unless ActiveRecord::Base.connected?
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
        end
        @connection ||= ActiveRecord::Base.connection
      end

      def execute_successful?(pg_function, lock_name)
        establish_connection
        sql = "SELECT #{pg_function}(#{stable_hashcode(lock_name)})"
        result = @connection.select_value(sql)
        (result == 't' || result == true)
      end

      def stable_hashcode(input)
        Zlib.crc32(input.to_s)
      end

    end
  end
end
