class MiqservicesClient
  include ScanningOperations # FIXME: This is code from the Rails app since it uses the models

  def method_missing(m, *args)
    meth = m.to_s.underscore
    return self.send(meth, *args) if self.respond_to?(meth)
    super
  end
end
