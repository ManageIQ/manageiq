# Optional logging of requires
if ENV["REQUIRE_LOG"]
  $req_log_path = File.join(File.dirname(__FILE__), %w(.. log))
  require 'require_with_logging'
end
