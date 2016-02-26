class << Process
  prepend(Module.new {
    def pid
      warn "Remove me: #{__FILE__}:#{__LINE__}.  Safe level 2-4 are no longer supported as of ruby 2.3!" if RUBY_VERSION >= "2.3"
      $SAFE < 2 ? super : 0
    end
  })
end
