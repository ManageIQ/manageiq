require 'csv'

class UiTask < ActiveRecord::Base
  default_scope :conditions => self.conditions_for_my_region_default_scope

  validates_presence_of     :area, :typ, :task, :name

  acts_as_miq_set_member

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  def self.seed_tasks
    $log.info("MIQ(UiTask.seed_tasks) Seeding tasks...")
    self.destroy_all

    fname = File.join(FIXTURE_DIR, "ui_tasks.csv")
    data  = CSV.parse(File.read(fname))
    cols  = data.shift
    data.each do |row|
      attrs = cols.inject({}) {|h,c| h[c.strip.to_sym] = row[cols.index(c)].strip unless row[cols.index(c)].nil?; h}
      $log.info("MIQ(UiTask.seed_tasks) Creating task: [#{attrs[:name]}]")
      self.create(attrs)
    end
    $log.info("MIQ(UiTask.seed_tasks) Seeding tasks... Complete")
  end

  def self.seed
    MiqRegion.my_region.lock do
      file_mtime = [File.mtime(File.join(FIXTURE_DIR, "ui_tasks.csv")).utc, File.mtime(File.join(FIXTURE_DIR, "ui_task_sets.map")).utc].sort.last
      rec = self.first(:order=> "updated_on DESC")

      if rec.nil? || rec.updated_on < file_mtime
        self.seed_tasks
        self.seed_roles
      end
    end
  end

  def self.seed_roles
    $log.info("MIQ(UiTask.seed_roles) Seeding roles...")
    roles = self.map_roles
    roles.each_key do |name|
      ts = UiTaskSet.find_by_name(name)
      if ts.nil?
        $log.info("MIQ(UiTask.seed_roles) Creating role: [#{name}]")
        ts = UiTaskSet.create(:name => name, :description => roles[name].first[:description])
      end
      ts.remove_all_members
      roles[name].each do |map|
        task = self.find_by_name(map[:task_name])
        next unless task

        ts.add_member(task)
      end
    end
    $log.info("MIQ(UiTask.seed_roles) Seeding roles... Complete")
  end

  def self.map_roles
    fname = File.join(FIXTURE_DIR, "ui_task_sets.map")
    data  = File.read(fname).split("\n")
    cols  = data.shift.split(",")

    mappings = {}
    data.each {|m|
      next if m =~ /^#.*$/ # skip commented lines

      arr = m.split(",")

      map = {}
      cols.each_index {|i| map[cols[i].to_sym] = arr[i]}
      mappings[map[:name]] ||= []
      mappings[map[:name]].push(map)
    }
    mappings
  end
end

