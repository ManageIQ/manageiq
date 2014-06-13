# The current imagefactory instance has ruby 1.8.7
# Once we're off of building on that machine, DELETE ME!
if RUBY_VERSION <= "1.8.7"
  require 'rubygems'
  module Kernel
    # Replaces Kernel's require_relative to allow it to be used in irb and eval
    # See: http://bugs.ruby-lang.org/issues/4487
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end

  class File
    def self.write(name, string)
      File.open(name, "w") do |f|
        f.write string
      end
    end
  end
end
