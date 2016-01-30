class << Process
  def pid_with_safe
    warn "Remove me: #{__FILE__}:#{__LINE__}.  Safe level 2-4 are no longer supported as of ruby 2.3!" if RUBY_VERSION >= "2.3"
    $SAFE < 2 ? pid_without_safe : 0
  end
  alias_method_chain :pid, :safe
end
