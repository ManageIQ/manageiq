class MiqservicesClientInternal
  include MiqservicesOps

  def method_missing(m, *args)
    meth = m.to_s.underscore
    return self.send(meth, *args) if self.respond_to?(meth)
    super
  end
end
