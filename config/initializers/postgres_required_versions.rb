ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Module.new {
  def initialize(*args)
    super

    if postgresql_version < 90400
      raise "The version of PostgreSQL being connected to is incompatible with #{I18n.t("product.name")} (9.4+ required)"
    end

    if postgresql_version >= 90600
      msg = "The version of PostgreSQL being connected to is incompatible with #{I18n.t("product.name")} (9.6+ is not supported yet)"

      raise msg if Rails.env.production? && !ENV["UNSAFE_PG_VERSION"]
      $stderr.puts msg
    end
  end
}
