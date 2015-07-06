require 'erb'
require 'yaml'

class MiqERBForYAML < ERB
  def initialize(str, safe_level=nil, trim_mode=nil, eoutvar='_erbout')
    str = quote_erb_tags(str) if defined?(Psych)
    super
  end

  private
  def quote_erb_tags(data)
    data.gsub(/<%= ([^>]+) %>/, '<%= Psych.to_json(\1).chomp %>')
  end
end
