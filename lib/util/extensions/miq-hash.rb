require 'more_core_extensions/core_ext/hash'

class Hash #:nodoc:

  # The following fixes a bug in Ruby where if subclasses of String are
  #   used as keys, and those subclasses have instance variables, then later
  #   calls to access the keys return the subclass type but the instance
  #   variables are missing.
  # TODO: Wrap this in a ruby version conditional depending on where this
  #       bug is present
  def bracket_equals_with_subclassed_string(key, value)
    key = key.dup.freeze if key.kind_of?(String) && !key.instance_of?(String)
    bracket_equals_without_subclassed_string(key, value)
  end
  alias bracket_equals_without_subclassed_string []=
  alias []= bracket_equals_with_subclassed_string
end
