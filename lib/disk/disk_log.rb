module DiskLog
  module ClassMethods
    def debug(msg)
      $log.debug msg if $log
    end

    def info(msg)
      $log.info msg if $log
    end

    def warn(msg)
      $log.warn msg if $log
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def debug(msg)
    self.class.debug msg
  end

  def info(msg)
    self.class.info msg
  end

  def warn(msg)
    self.class.warn msg
  end
end
