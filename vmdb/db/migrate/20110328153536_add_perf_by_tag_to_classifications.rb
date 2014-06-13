class AddPerfByTagToClassifications < ActiveRecord::Migration
  class Tag < ActiveRecord::Base
  end

  class Classification < ActiveRecord::Base
    include ReservedMixin

    belongs_to :tag, :class_name => "AddPerfByTagToClassifications::Tag"

    def self.categories(region_id = self.my_region_number, ns = "/managed")
      cats = self.in_region(region_id).where(:parent_id => 0).includes(:tag)
      cats.select { |c| c.tag2ns(c.tag.name) == ns }
    end

    def tag2ns(tag)
      unless tag.nil?
        ta = tag.split("/")
        ta[0..(ta.length-2)].join("/")
      end
    end

    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :classifications, :perf_by_tag, :boolean

    say_with_time("Migrate data from reserved table") do
      cats = Classification.categories
      ActiveRecord::Associations::Preloader.new(cats, :reserved_rec).run
      cats.each do |cat|
        cat.reserved_hash_migrate(:perf_by_tag)
      end
    end
  end

  def self.down
    remove_column :classifications, :perf_by_tag
  end
end
