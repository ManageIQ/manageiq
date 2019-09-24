ActiveSupport::Notifications.subscribe('instantiation.active_record') do |name, start, finish, _id, payload|
  logger = ActiveRecord::Base.logger
  if logger.debug?
    elapsed = finish - start
    name = payload[:class_name]
    count = payload[:record_count]

    logger.debug('  %s Inst Including Associations (%.1fms - %drows)' % [name || 'SQL', (elapsed * 1000), count])
  end
end
