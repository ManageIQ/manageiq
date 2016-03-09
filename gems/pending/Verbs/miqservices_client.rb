class MiqservicesClient
  # TODO: Remove remaining users of this client in MiqVerbs/SharedOps/VmdbOps/WebSvcOps
  def method_missing(m, *args)
    meth = m.to_s.underscore
    return send(meth, *args) if self.respond_to?(meth)
    super
  end
end
