module PostgresHaAdmin
  module PostgresHaLogger
    attr_reader :log_file

    def init_logger(log_dir)
      @log_file = Pathname.new(log_dir).join('ha_admin.log')
    end

    def log_info(message)
      File.open(log_file, 'a') do |f|
        f.write "[----] I, [#{Time.now.utc.iso8601(6)} ##{Process.pid}:"\
            "#{Thread.current.object_id.to_s(16)}]  INFO -- : #{self.class.name} - #{message}"
      end
    end

    def log_error(message)
      File.open(log_file, 'a') do |f|
        f.write "[----] E, [#{Time.now.utc.iso8601(6)} ##{Process.pid}:"\
            "#{Thread.current.object_id.to_s(16)}]  ERROR -- : #{self.class.name} - #{message}"
      end
    end
  end
end
