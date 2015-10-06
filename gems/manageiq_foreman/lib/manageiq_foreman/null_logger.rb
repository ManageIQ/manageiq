require 'logger'

module ManageiqForeman
  class NullLogger < Logger
    def initialize(*_args)
    end

    def add(*_args, &_block)
    end
  end
end
