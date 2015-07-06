module ProviderObjectMixin
  def with_provider_connection(options = {})
    raise "no block given" unless block_given?

    connection_source(options).with_provider_connection(options) do |connection|
      yield connection
    end
  end

  def with_provider_object(options = {})
    raise "no block given" unless block_given?

    connection_source(options).with_provider_connection(options) do |connection|
      begin
        handle = provider_object(connection)
        yield handle
      ensure
        provider_object_release(handle) if handle && self.respond_to?(:provider_object_release)
      end
    end
  end

  def provider_object(connection = nil)
    raise NotImplementedError, "not implemented in #{self.class.name}"
  end

  private

  def connection_source(options = {})
    source = options[:connection_source] || self.ext_management_system
    raise "no connection source available" if source.nil?
    source
  end
end