require 'more_core_extensions/core_ext/array'

class Object #:nodoc:
  def to_miq_a
    [*self]
  end
end

class String
  def to_miq_a
    self.lines.to_a
  end
end

class Array
  def to_miq_a
    self.to_a
  end
end

class Hash
  def to_miq_a
    [self]
  end
end

class NilClass
  def to_miq_a
    []
  end
end

# ActiveRecord's AssociationProxy (base class for HasOne, HasMany, etc.) 
#   undefines nearly every method from Object, as part of it's delayed loading
#   infrastructure.  However, since we may define to_miq_a after this happens,
#   we end up adding the method at the wrong level.  This ends up causing the
#   warning during some invocations:
#     "warning: default `to_a' will be obsolete"
#
#   This issue is fixed by removing the method from the AssociationProxy if it
#   is defined.  If it ends up being defined later, the method will be removed
#   during it's normal removal of methods
ActiveRecord::Associations::AssociationProxy.send(:undef_method, :to_miq_a) rescue nil
