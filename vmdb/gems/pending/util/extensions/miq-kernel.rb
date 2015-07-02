module Kernel
  # $LOAD_PATH is an alias for $:
  def add_to_load_path(path)
    path = File.expand_path(path)
    $:.push(path) unless $:.include?(path)
  end

  # Replaces Kernel's require_relative to allow it to be used in irb and eval
  # See: http://bugs.ruby-lang.org/issues/4487
  def require_relative(path)
    require File.join(File.dirname(caller[0]), path.to_str)
  end
end
