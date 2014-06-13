class MiqDialog < ActiveRecord::Base
  validates_presence_of   :name, :description
  validates_uniqueness_of :name, :scope => :dialog_type, :case_sensitive => false

  DIALOG_DIR = File.expand_path(File.join(Rails.root, "product/dialogs"))

  DIALOG_TYPES = [
    ["VM Provision"  , "MiqProvisionWorkflow"    ],
    ["Host Provision", "MiqHostProvisionWorkflow"],
    ["VM Migrate", "VmMigrateWorkflow"],
  ]

  serialize :content

  include ReportableMixin

  def self.seed
    MiqRegion.my_region.lock do
      self.sync_from_dir
    end
  end

  def self.sync_from_dir
    Dir.glob(File.join(DIALOG_DIR, "*.yaml")).each {|f| self.sync_from_file(f)}
  end

  def self.sync_from_file(filename)
    log_header = "MiqDialog.sync_from_file"
    item = YAML.load_file(filename)

    item[:filename] = filename.sub(DIALOG_DIR + "/", "")
    item[:file_mtime] = File.mtime(filename).utc
    item[:default] = true

    rec = self.find_by_name_and_filename(item[:name], item[:filename])

    if rec
      if rec.filename && (rec.file_mtime.nil? || rec.file_mtime.utc < item[:file_mtime])
        $log.info("#{log_header}: [#{rec.name}] file has been updated on disk, synchronizing with model")
        rec.update_attributes(item)
        rec.save
      end
    else
      $log.info("#{log_header}: [#{item[:name]}] file has been added to disk, adding to model")
      self.create(item)
    end
  end

end
