module SeedingMixin
  extend ActiveSupport::Concern

  AssociationSeed = Struct.new(:name, :type, :find_by, :add_proc)
  module ClassMethods
    def with_many(association, find_by = :guid, add_proc = nil)
      add_proc ||= ->(p, c) { p.send("#{association}=", p.send(association) << c) }
      AssociationSeed.new(association, :has_many, find_by, add_proc)
    end

    def with_one(association, find_by = :guid)
      add_proc = ->(p, c) { p.send("#{association}=", c) }
      AssociationSeed.new(association, :has_one, find_by, add_proc)
    end

    def seed_model(*associations)
      load_fixtures(name.tableize).each do |hash|
        rec = seed_attributes!(self, hash.except(*associations.map(&:name)))
        seed_associations(rec, hash, associations)
        rec.save!
      end
    end

    private

    def seed_attributes!(model, hash)
      rec = model.find_by(:guid => hash[:guid])
      if rec.nil?
        _log.info("Creating #{model.name}: [#{hash[:guid]}]")
        rec = model.create(hash)
      else
        _log.info("Updating #{model.name}: [#{hash[:guid]}]")
        rec.assign_attributes(hash)
      end
      rec
    end

    def seed_associations(rec, hash, associations)
      associations.each do |association|
        seed_association(rec, hash, association)
      end
    end

    def seed_association(parent, hash, association)
      return if hash[association.name].blank?
      if association.type == :has_one
        seed_association_item(parent, hash[association.name], association)
      else
        hash[association.name].each do |relation|
          seed_association_item(parent, relation, association)
        end
      end
    end

    def seed_association_item(parent, relation, association)
      clazz = association.name.to_s.classify.constantize
      item = clazz.find_by(association.find_by => relation)
      association.add_proc.call(parent, item) unless item.nil?
    end

    def load_fixtures(fixture_name)
      fixture_file = File.join(ApplicationRecord::FIXTURE_DIR, "#{fixture_name}.yml")
      File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
    end
  end
end
