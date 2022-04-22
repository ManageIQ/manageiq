module PhysicalServer::Operations
  extend ActiveSupport::Concern

  include_concern 'Power'
  include_concern 'Led'
  include_concern 'ConfigPattern'
  include_concern 'Lifecycle'

  private

  def change_state(verb)
    unless ext_management_system
      raise _(" A Server %{server} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:server => self, :name => name, :id => id}
    end
    options = {:uuid => ems_ref}
    _log.info("Begin #{verb} server: #{name}  with UUID: #{ems_ref}")
    ext_management_system.send(verb, self, options)
    _log.info("Complete #{verb} #{self}")
  end
end
