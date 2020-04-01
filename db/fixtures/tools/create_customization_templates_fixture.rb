recs = CustomizationTemplate.where(:system => true).order(Arel.sql("LOWER(name)"))
recs = recs.collect do |r|
  attrs = r.attributes.except("id", "created_at", "updated_at", "pxe_image_type_id").symbolize_keys
  attrs[:system] = true
  attrs
end
File.open(CustomizationTemplate.seed_file_name, "w") do |f|
  f.write(recs.to_yaml)
end
