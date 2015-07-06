ActiveSupport::Notifications.subscribe('instantiation.active_record') do |name, start, finish, id, payload|
  elapsed = finish - start
  name = payload[:class_name]
  count = payload[:record_count]
  logger = ActiveRecord::Base.logger

  logger.debug('  %s Inst Including Associations (%.1fms - %drows)' % [name || 'SQL', (elapsed * 1000), count])
end
