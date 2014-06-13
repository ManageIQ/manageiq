module CloudInitTemplateMixin

  def allowed_cloud_init_customization_templates(options={})
    result = []
    customization_template_id = get_value(@values[:customization_template_id])
    @values[:customization_template_script] = nil if customization_template_id.nil?
    result = CustomizationTemplateCloudInit.all.collect do |c|
      @values[:customization_template_script] = c.script if c.id == customization_template_id
      build_ci_hash_struct(c, [:name, :description, :updated_at])
    end

    result.compact!
    @values[:customization_template_script] = nil if result.blank?
    return result
  end

end
