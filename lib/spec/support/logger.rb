def init_logger
  $log ||= Log4r::Logger.new 'miq-disk-spec'
end
