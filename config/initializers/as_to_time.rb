require 'active_support/core_ext/string/conversions'
require 'active_support/deprecation'

class String
  alias_method :old_to_time, :to_time

  OBJ = Object.new

  def to_time(form = OBJ)
    if form == OBJ
      ActiveSupport::Deprecation.warn("Rails 4 changes the default of String#to_time to local.  Please pass the type of conversion you want, like to_time(:utc) or to_time(:local)", caller.drop(1))
      old_to_time(:utc)
    else
      old_to_time(form)
    end
  end
end
