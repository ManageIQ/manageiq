# lib and lib/util are required so often, we just make it globally available
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. lib})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. lib util})))

# To evaluate ERB from database.yml containing encrypted passwords
require 'miq-password'

# Optional logging of requires
if ENV["REQUIRE_LOG"]
  $req_log_path = File.join(File.dirname(__FILE__), %w{.. log})
  require 'require_with_logging'
end

# Optionally print GC information to STDERR on a signal (default: :SIGALRM)
if $print_gc_on_signal
  # Enable/disable extra GC statistics (adds some overhead)
  $print_extra_gc_stats ||= false

  require 'miq_ree_gc'
  MiqReeGc.print_gc_info_on_signal($print_extra_gc_stats, :SIGALRM)
end
