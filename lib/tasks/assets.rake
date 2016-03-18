namespace :assets do
  task :precompile => 'assets:env'

  desc 'Too late to set an environment variable, raise an exception if LOAD_ASSETs is not set'
  task :env do
    unless ENV['LOAD_ASSETS']
      raise "Please set the LOAD_ASSETS environment variable to true if you want to precompile assets!"
    end
  end
end
