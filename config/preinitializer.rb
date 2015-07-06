# gems/pending and gems/pending/util are required so often, we just make it globally available
GEMS_PENDING_ROOT = File.expand_path(File.join(__dir__, %w(.. gems pending)))
$LOAD_PATH << GEMS_PENDING_ROOT
$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "util")

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
