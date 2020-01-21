module CloudInitTemplateMixin
  def allowed_cloud_init_customization_templates(_options = {})
    result = []
    return result if (source = load_ar_obj(get_source_vm)).blank?

    customization_template_id = get_value(@values[:customization_template_id])
    @values[:customization_template_script] = nil if customization_template_id.nil?

    result = CustomizationTemplateCloudInit.in_region(source.region_number).all.collect do |c|
      @values[:customization_template_script] = c.script if c.id == customization_template_id
      build_ci_hash_struct(c, [:name, :description, :updated_at])
    end

    result.compact!
    @values[:customization_template_script] = nil if result.blank?
    result
  end
end
