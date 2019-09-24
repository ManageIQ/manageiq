if ENV['RACK_RUBY_PROF']
  output = Rails.root.join('tmp/rack_ruby_prof')
  puts "** Rack::RubyProf is enabled, each request will dump to '#{output}'."
  puts "** Unset RACK_RUBY_PROF to turn off profiling."

  begin
    require 'ruby-prof'
  rescue LoadError
    puts "Failed! Please make sure ruby-prof is in your Gemfile."
  else
    Rails.application.config.middleware.use(
      Rack::RubyProf,
      :path        => output,
      :printers    => {RubyProf::CallStackPrinter => 'call_stack.html'},
      :min_percent => 2
    )
  end
end
