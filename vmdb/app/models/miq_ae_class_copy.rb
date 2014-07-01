class MiqAeClassCopy
  include MiqAeCopyMixin
  DELETE_PROPERTIES = %w(updated_by updated_by_user_id updated_on id
                         created_on updated_on method_id owner class_id)

  def initialize(class_fqname)
    @class_fqname = class_fqname
    @src_domain, @partial_ns, @ae_class = MiqAeClassCopy.split(@class_fqname, false)
    @src_class = MiqAeClass.find_by_fqname(@class_fqname)
    raise "Source class not found #{@class_fqname}" unless @src_class
  end

  def to_domain(domain, ns = nil, overwrite = false)
    check_duplicity(domain, ns, @src_class.name)
    @overwrite        = overwrite
    @target_ns_fqname = target_ns(domain, ns)
    @target_name      = @src_class.name
    copy
  end

  def as(new_name, ns = nil, overwrite = false)
    check_duplicity(@src_domain, ns, new_name)
    @overwrite        = overwrite
    @target_ns_fqname = target_ns(@src_domain, ns)
    @target_name      = new_name
    copy
  end

  private

  def target_ns(domain, ns)
    return "#{domain}/#{@partial_ns}" if ns.nil?
    MiqAeNamespace.find_by_fqname(ns, false).nil? ? "#{domain}/#{ns}" : ns
  end

  def copy
    validate
    create_class
    copy_schema
    @dest_class
  end

  def create_class
    ns = MiqAeNamespace.find_or_create_by_fqname(@target_ns_fqname, false)
    ns.save!
    @dest_class = MiqAeClass.create!(:namespace_id => ns.id,
                                     :name         => @target_name,
                                     :description  => @src_class.description,
                                     :type         => @src_class.type,
                                     :display_name => @src_class.display_name,
                                     :inherits     => @src_class.inherits,
                                     :visibility   => @src_class.visibility)
  end

  def copy_schema
    @dest_class.ae_fields = add_fields
    @dest_class.save!
  end

  def add_fields
    @src_class.ae_fields.collect do |src_field|
      attrs = src_field.attributes.reject { |k, _| DELETE_PROPERTIES.include?(k) }
      MiqAeField.new(attrs)
    end
  end

  def validate
    dest_class = MiqAeClass.find_by_fqname("#{@target_ns_fqname}/#{@target_name}")
    if dest_class
      dest_class.destroy if @overwrite
      raise "Destination Class already exists #{dest_class.fqname}" unless @overwrite
    end
  end

  def check_duplicity(domain, ns, classname)
    if domain.downcase == @src_domain.downcase && classname.downcase == @ae_class.downcase
      raise "Cannot copy class onto itself" if ns.nil? || ns.downcase == @partial_ns.downcase
    end
  end
end
