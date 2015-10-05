# gems/pending and gems/pending/util are required so often, we just make it globally available
GEMS_PENDING_ROOT = File.expand_path(File.join(__dir__, %w(.. gems pending)))
$LOAD_PATH << GEMS_PENDING_ROOT
$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "util")

# To evaluate ERB from database.yml containing encrypted passwords
require 'miq-password'

# Optional logging of requires
if ENV["REQUIRE_LOG"]
  $req_log_path = File.join(File.dirname(__FILE__), %w(.. log))
  require 'require_with_logging'
end
