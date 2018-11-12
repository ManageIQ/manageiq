ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Module.new {
  def initialize(*args)
    super

    if postgresql_version < 90500
      raise "The version of PostgreSQL being connected to is incompatible with #{Vmdb::Appliance.PRODUCT_NAME} (9.5 required)"
    end

    if postgresql_version >= 90600
      msg = "The version of PostgreSQL being connected to is incompatible with #{Vmdb::Appliance.PRODUCT_NAME} (9.6+ is not supported yet)"

      raise msg if Rails.env.production? && !ENV["UNSAFE_PG_VERSION"]
      $stderr.puts msg
    end
  end
}
