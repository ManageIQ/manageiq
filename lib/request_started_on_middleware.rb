# Add to config/application.rb:
#
#     config.middleware.use 'RequestStartedOnMiddleware'
#
class RequestStartedOnMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start_request(env['PATH_INFO'], Time.zone.now)
    @app.call(env)
  ensure
    complete_request
  end

  def start_request(path_info, started_on)
    Thread.current[:current_request_path_info]  = path_info
    Thread.current[:current_request_started_on] = started_on
  end

  def complete_request
    Thread.current[:current_request_path_info]  = nil
    Thread.current[:current_request_started_on] = nil
  end

  def self.long_running_requests
    requests = []
    allowable_request_start_time = long_request.ago

    relevant_thread_list.each do |thread|
      request    = thread[:current_request_path_info]
      started_on = thread[:current_request_started_on]

      # There's a race condition where the complete_request method runs in another
      # thread after we set one or more of the above local variables. The fallout
      # of this is we return a false positive for a request that finished very close
      # to the 2 minute timeout.
      if request.present? && started_on.kind_of?(Time) && started_on < allowable_request_start_time
        duration = (Time.zone.now - started_on).to_f
        requests << [request, duration, thread]
      end
    end

    requests
  end

  LONG_REQUEST = 1.minute
  private_class_method def self.long_request
    LONG_REQUEST
  end

  # For testing: mocking Thread.list feels dangerous
  private_class_method def self.relevant_thread_list
    Thread.list
  end
end
