module Vmdb::ConsoleMethods
  module LogLevelToggle
    def enable_console_sql_logging
      ActiveRecord::Base.logger.level = 0
    end

    def disable_console_sql_logging
      ActiveRecord::Base.logger.level = 1
    end

    def toggle_console_sql_logging
      ActiveRecord::Base.logger.level == 0 ? disable_console_sql_logging : enable_console_sql_logging
    end

    def with_console_sql_logging_level(level)
      old_level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger.level = level
      yield
    ensure
      ActiveRecord::Base.logger.level = old_level
    end
  end
end
