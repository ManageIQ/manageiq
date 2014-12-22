class MiqEventSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope { where self.conditions_for_my_region_default_scope }

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  def self.seed
    MiqRegion.my_region.lock do
      fname = File.join(FIXTURE_DIR, "#{self.to_s.pluralize.underscore}.csv")
      data  = File.read(fname).split("\n")
      cols  = data.shift.split(",")

      data.each do |s|
        next if s =~ /^#.*$/ # skip commented lines

        arr = s.split(",")

        set = {}
        cols.each_index {|i| set[cols[i].to_sym] = arr[i]}

        rec = self.find_by_name(set[:name])
        if rec.nil?
          $log.info("MIQ(MiqEventSet.seed) Creating [#{set[:name]}]")
          rec = self.create(set)
        else
          rec.attributes = set
          if rec.changed?
            $log.info("MIQ(MiqEventSet.seed) Updating [#{set[:name]}]")
            rec.save
          end
        end
      end
    end
  end

end
