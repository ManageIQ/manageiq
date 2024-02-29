recs = PxeImageType.order(Arel.sql("LOWER(name)")).collect { |r| r.attributes.except("id").symbolize_keys }
File.write(PxeImageType.seed_file_name, recs.to_yaml)
