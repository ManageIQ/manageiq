class YamlPermittedClasses
  DEFAULT_PERMITTED_CLASSES = [Object, Regexp, Symbol, Date, Time, ActiveSupport::HashWithIndifferentAccess, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  def self.app_yaml_permitted_classes
    @app_yaml_permitted_classes ||= DEFAULT_PERMITTED_CLASSES + [MiqExpression, MiqReport, Ruport::Data::Table, Ruport::Data::Record, User]
  end

  def self.default_permitted_classes
    @default_permitted_classes ||= DEFAULT_PERMITTED_CLASSES
  end

  def self.initialize_app_yaml_permitted_classes
    @initialize_app_yaml_permitted_classes ||= begin
      ActiveRecord::Base.yaml_column_permitted_classes = YamlPermittedClasses.app_yaml_permitted_classes
      true
    end
  end

  def self.initialized?
    !!@initialize_app_yaml_permitted_classes
  end
end
