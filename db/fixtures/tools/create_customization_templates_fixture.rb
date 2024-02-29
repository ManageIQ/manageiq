recs = CustomizationTemplate.where(:system => true).order(Arel.sql("LOWER(name)"))
recs = recs.collect do |r|
  attrs = r.attributes.except("id", "created_at", "updated_at", "pxe_image_type_id").symbolize_keys
  attrs[:system] = true
  attrs
end
File.write(CustomizationTemplate.seed_file_name, recs.to_yaml)
