module RelativePathMixin
  extend ActiveSupport::Concern

  included do
    virtual_attribute :lower_name, :string, :arel => ->(t) { t.grouping(t[:name].lower) }
    virtual_attribute :lower_relative_path, :string, :arel => ->(t) { t.grouping(t[:relative_path].lower) }
  end

  def fqname
    ["", domain_name, relative_path].compact.join("/")
  end

  def lower_name
    name&.downcase
  end

  def lower_relative_path
    rel_path&.downcase
  end

  def domain_name
    MiqAeDomain.id_to_name(domain_id)
  end

  # TODO: after save?

  module ClassMethods
    def split_fqname(fqname)
      fqname = fqname[1..-1] if fqname[0] == '/'
      fqname.split('/')
    end
  end
end
