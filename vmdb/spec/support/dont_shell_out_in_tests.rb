require 'runcmd'

class MiqUtil
  def self.runcmd(*_args)
    raise "Don't shell out in tests!  Mock me instead!"
  end
end
