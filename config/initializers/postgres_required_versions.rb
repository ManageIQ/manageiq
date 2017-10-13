ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend Module.new {
  def initialize(*args)
    super
    if postgresql_version < 90400 || postgresql_version >= 90600
      msg = "The version of PostgreSQL being connected to is incompatible with #{I18n.t("product.name")}"

      raise msg if Rails.env.production?
      $stderr.puts msg
    end
  end
}
