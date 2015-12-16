require 'ruby_parser'

module RubyParserRuby23Bridge
  def for_current_ruby
    result = super
  rescue => e
    if e.message.include?("unrecognized RUBY_VERSION 2.3")
      Ruby22Parser.new
    else
      raise
    end
  else
    warn "Remove me: #{__FILE__}:#{__LINE__}.  RubyParser now supports ruby 2.3+" if RUBY_VERSION.match(/^2.3/)
    result
  end
end

RubyParser.singleton_class.prepend RubyParserRuby23Bridge
