class MiqDialog < ApplicationRecord
  validates_presence_of   :name, :description
  validates_uniqueness_of :name, :scope => :dialog_type, :case_sensitive => false

  DIALOG_DIR = Rails.root.join("product/dialogs/miq_dialogs")

  DIALOG_TYPES = [
    ["VM Provision",                "MiqProvisionWorkflow"],
    ["Configured System Provision", "MiqProvisionConfiguredSystemWorkflow"],
    ["Host Provision",              "MiqHostProvisionWorkflow"],
    ["VM Migrate",                  "VmMigrateWorkflow"],
  ]

  serialize :content

  include ReportableMixin

  def self.seed
    sync_from_dir
  end

  def self.sync_from_dir
    Dir.glob(File.join(DIALOG_DIR, "*.yaml")).each { |f| sync_from_file(f) }
  end

  def self.sync_from_file(filename)
    item = YAML.load_file(filename)

    item[:filename] = filename.sub(DIALOG_DIR.to_path + "/", "")
    item[:file_mtime] = File.mtime(filename).utc
    item[:default] = true

    rec = find_by(:name => item[:name], :filename => item[:filename])

    if rec
      if rec.filename && (rec.file_mtime.nil? || rec.file_mtime.utc < item[:file_mtime])
        _log.info("[#{rec.name}] file has been updated on disk, synchronizing with model")
        rec.update_attributes(item)
        rec.save
      end
    else
      _log.info("[#{item[:name]}] file has been added to disk, adding to model")
      create(item)
    end
  end
end
