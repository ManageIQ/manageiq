module SeedingMixin
  extend ActiveSupport::Concern
  # Seeding mixin can be used as long as fixture association
  # are not nested but of the form: (for a hash_many relationship
  #   :miq_policies:
  #   - c5ceab70-da38-11e5-9cae-0242782a2608
  #   - de0650f6-2412-4bea-b272-85ae7c9f61f3
  module ClassMethods
    def seed_model(model, options = {})
      filter = options[:find_by] || -> (hash) { {:guid => hash[:guid]} }

      load_fixtures(model.name.tableize).each do |hash|
        association = options[:has_many].nil? ? nil : options[:has_many][0]
        rec = seed_attributes!(model, hash.except(association), filter)
        seed_relationships(rec, hash, options) if options[:has_many]
        rec.save!
      end
    end

    def seed_attributes!(model, hash, filter)
      key = filter.call(hash)
      rec = model.find_by(key)

      hash.merge!(key)
      if rec.nil?
        _log.info("Creating #{model.name}: #{key}")
        rec = model.create(hash)
      else
        _log.info("Updating #{model.name}: #{key}")
        rec.assign_attributes(hash)
      end
      rec
    end

    def seed_relationships(rec, hash, options)
      assoc = options[:has_many][0]
      assoc_class = assoc.to_s.classify.constantize
      assoc_method = options[:has_many][1]

      hash[assoc].each do |guid|
        item = assoc_class.find_by_guid(guid)
        assoc_method.call(rec, assoc_class.find_by_guid(guid)) unless item.nil?
      end
    end

    def load_fixtures(fixture_name)
      fixture_file = File.join(ApplicationRecord::FIXTURE_DIR, "#{fixture_name}.yml")
      File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
    end
  end
end
