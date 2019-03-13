ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Module.new {
  def initialize(*args)
    super

    msg = "The version of PostgreSQL being connected to is incompatible with #{Vmdb::Appliance.PRODUCT_NAME} (10 required)"

    if postgresql_version < 90500
      raise msg
    end

    if postgresql_version < 100000 || postgresql_version >= 110000
      raise msg if Rails.env.production? && !ENV["UNSAFE_PG_VERSION"]
      $stderr.puts msg
    end
  end
}
