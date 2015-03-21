class << Process
  def pid_with_safe
    $SAFE < 2 ? pid_without_safe : 0
  end
  alias_method_chain :pid, :safe
end
