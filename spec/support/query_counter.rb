# Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed

class QueryCounter
  def self.count(&block)
    new.count(&block)
  end

  IGNORED_STATEMENTS = %w(CACHE SCHEMA)

  def callback(_name, _start, _finish, _id, payload)
    @count += 1 unless IGNORED_STATEMENTS.include?(payload[:name])
  end

  def callback_proc
    lambda(&method(:callback))
  end

  def count(&block)
    @count = 0
    ActiveSupport::Notifications.subscribed(callback_proc, 'sql.active_record', &block)
    @count
  end
end

class QuerySubscriber
  attr_reader :locations

  def initialize
    @locations = Hash.new(0)
  end

  def start(_name, _id, _payload)
    app_caller = caller.detect { |c| c !~ /rails\-|factory_girl|ancestry|default_value_for|rspec|activerecord-deprecated_finders|\.rubies|lib\/extensions\/ar/ }
    @locations[app_caller] += 1 if app_caller
  end

  def finish(name, id, payload); end

  def self.print_top_query_locations(top = 20)
    subscriber = new
    ActiveSupport::Notifications.subscribe('sql.active_record', subscriber)
    at_exit do
      puts "Top query locations:"
      subscriber.locations.sort_by { |_loc, count| -count }.take(top).each do |loc, count|
        puts "#{count} #{loc}"
      end
    end
  end
end

QuerySubscriber.print_top_query_locations
