class MiqAeMethodCopy
  include MiqAeCopyMixin
  DELETE_PROPERTIES = %w(id class_id method_id field_id updated_on created_on
                         updated_by updated_by_user_id)

  def initialize(method_fqname)
    @src_domain, @partial_ns, @ae_class, @method_name = MiqAeMethodCopy.split(method_fqname, true)
    @class_fqname = "#{@src_domain}/#{@partial_ns}/#{@ae_class}"
    @src_class = MiqAeClass.find_by_fqname("#{@src_domain}/#{@partial_ns}/#{@ae_class}")
    raise "Source class not found #{@class_fqname}" unless @src_class
    @src_method = MiqAeMethod.find_by_name_and_class_id(@method_name, @src_class.id)
    raise "Source method #{@method_name} not found #{@class_fqname}" unless @src_method
    @target_class_name = @ae_class
  end

  def to_domain(domain, ns = nil, overwrite = false)
    check_duplicity(domain, ns, @method_name)
    @overwrite        = overwrite
    @target_ns        = ns.nil? ? @partial_ns : ns
    @target_name      = @method_name
    @target_domain    = domain
    copy
  end

  def as(new_name, ns = nil, overwrite = false)
    check_duplicity(@src_domain, ns, new_name)
    @overwrite        = overwrite
    @target_ns        = ns.nil? ? @partial_ns : ns
    @target_name      = new_name
    @target_domain    = @src_domain
    copy
  end

  private

  def find_or_create_class
    @dest_class = MiqAeClass.find_by_fqname("#{@target_domain}/#{@target_ns}/#{@target_class_name}")
    return unless @dest_class.nil?
    @dest_class = MiqAeClassCopy.new(@class_fqname).to_domain(@target_domain, @target_ns)
  end

  def copy
    validate
    create_method
    @dest_method.inputs << add_inputs
    @dest_method.save!
    @dest_method
  end

  def add_inputs
    @src_method.inputs.collect do |v|
      attrs = v.attributes.delete_if { |k, _| DELETE_PROPERTIES.include?(k) }
      MiqAeField.new(attrs)
    end
  end

  def create_method
    @dest_method = MiqAeMethod.find_by_class_id_and_name(@dest_class.id, @target_name)
    if @dest_method
      @dest_method.destroy if @overwrite
      raise "Instance #{@target_name} exists in #{@target_ns_fqname} class #{@target_class_name}" unless @overwrite
    end
    @dest_method = MiqAeMethod.create!(:name         => @target_name,
                                       :display_name => @src_method.display_name,
                                       :description  => @src_method.description,
                                       :scope        => @src_method.scope,
                                       :language     => @src_method.language,
                                       :location     => @src_method.location,
                                       :data         => @src_method.data,
                                       :class_id     => @dest_class.id)
  end

  def validate
    find_or_create_class
  end

  def check_duplicity(domain, ns, method_name)
    if domain.downcase == @src_domain.downcase && method_name.downcase == @method_name.downcase
      raise "Cannot copy method onto itself" if ns.nil? || ns.downcase == @partial_ns.downcase
    end
  end
end
