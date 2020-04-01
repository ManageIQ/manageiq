recs = PxeImageType.order(Arel.sql("LOWER(name)")).collect { |r| r.attributes.except("id").symbolize_keys }
File.open(PxeImageType.seed_file_name, "w") do |f|
  f.write(recs.to_yaml)
end
