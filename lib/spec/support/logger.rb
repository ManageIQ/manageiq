require 'log4r'

def init_logger
  $log ||= Log4r::Logger.new 'miq-disk-spec'
end
