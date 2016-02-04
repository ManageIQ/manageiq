module MiqConcurrency
  module PGMutex
    class << self
      require 'zlib'
      require 'securerandom'

      def try_advisory_lock(lock_name)
        establish_connection()
        hashcode = stable_hashcode(lock_name)
        execute_successful?('pg_try_advisory_lock', hashcode)
      end

      def release_advisory_lock(lock_name)
        establish_connection()
        hashcode = stable_hashcode(lock_name)
        execute_successful?('pg_advisory_unlock', hashcode)
      end

      def count_advisory_lock(lock_name)
        establish_connection()
        hashcode = stable_hashcode(lock_name)
        sql = "SELECT count(*) from pg_locks where locktype = 'advisory' and classid = #{hashcode} and pid = pg_backend_pid()"
        @connection.select_value(sql).to_i
      end

      private

      def establish_connection()
        unless ActiveRecord::Base.connected?
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
        end
        unless @connection
          @connection = ActiveRecord::Base.connection
        end
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
