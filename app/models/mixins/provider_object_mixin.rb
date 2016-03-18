module ProviderObjectMixin
  def with_provider_connection(options = {})
    raise _("no block given") unless block_given?

    connection_source(options).with_provider_connection(options) do |connection|
      yield connection
    end
  end

  def with_provider_object(options = {})
    raise _("no block given") unless block_given?
    connection_source(options).with_provider_connection(options) do |connection|
      begin
        handle = provider_object(connection)
        yield handle
      ensure
        provider_object_release(handle) if handle && self.respond_to?(:provider_object_release)
      end
    end
  end

  def provider_object(_connection = nil)
    raise NotImplementedError, _("not implemented in %{class_name}") % {:class_name => self.class.name}
  end

  private

  def connection_source(options = {})
    source = options[:connection_source] || connection_manager
    raise _("no connection source available") if source.nil?
    source
  end

  def connection_manager
    try(:ext_management_system) || try(:manager)
  end
end
