ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Module.new do
  def initialize(*args)
    super
    check_version if respond_to?(:check_version)
  end

  def check_version
    msg = "The version of PostgreSQL being connected to (#{postgresql_version}) is incompatible with #{Vmdb::Appliance.PRODUCT_NAME} (130000 / 13 required)"

    if postgresql_version < 10_00_00
      raise msg
    end

    if postgresql_version >= 14_00_00
      warn msg
    end
  end
end)
