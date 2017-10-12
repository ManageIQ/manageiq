ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Module.new {
  def initialize(*args)
    super
    if postgresql_version < 90400 || postgresql_version >= 90600
      raise "The version of PostgreSQL being connected to is incompatible with #{I18n.t("product.name")}"
    end
  end
}
