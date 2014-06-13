module MiqReport::Seeding
  extend ActiveSupport::Concern

  module ClassMethods

    REPORT_DIR  = File.expand_path(File.join(Rails.root, "product/reports"))
    COMPARE_DIR = File.expand_path(File.join(Rails.root, "product/compare"))

    def seed
      MiqRegion.my_region.lock do
        # Force creation of model instances for all report yaml files that exist in the product/reports directories
        # that don't already have an instance in the model
        MiqReport.sync_from_dir("report")
        MiqReport.sync_from_dir("compare")
      end
    end

    def seed_report(pattern, type = "report")
      dir = type == "report" ? REPORT_DIR : COMPARE_DIR
      files = Dir.glob(File.join(dir, "**/*#{pattern}*"))
      files.collect do |f|
        self.sync_from_file(f, dir, type)
      end
    end

    def sync_from_dir(typ)
      if typ == "report"
        dir = REPORT_DIR
        pattern = "*/*.yaml"
        cond = ["rpt_type = 'Default' and (template_type = ? or template_type is null)", typ]
      else
        dir = COMPARE_DIR
        pattern = "*.yaml"
        cond = ["rpt_type = 'Default' and template_type = ?", typ]
      end

      self.find(:all, :conditions => cond).each do |f|
        next unless f.filename
        unless File.exists?(File.join(dir, f.filename))
          $log.info("#{typ.titleize}: file [#{f.filename}] has been deleted from disk, deleting from model")
          f.destroy
        end
      end

      Dir.glob(File.join(dir, pattern)).sort.each do |f|
        self.sync_from_file(f, dir, typ)
      end
    end

    def sync_from_file(filename, dir, typ)
      fd = File.open(filename)
      fd.gets # throw away "--- !ruby/object:MIQ_Report \r\n"
      yml = YAML.load(fd.read)
      fd.close

      rpt = {}
      self.column_names.each {|c| rpt[c.to_sym] = yml[c]}
      # rpt[:name] = File.basename(filename, ".*")
      rpt[:name] = yml["menu_name"].strip
      rpt[:rpt_group] = File.basename(File.dirname(filename)).split("_").last
      rpt[:rpt_type] = "Default"
      rpt[:filename] = filename.sub(dir + "/", "")
      rpt[:file_mtime] = File.mtime(filename).utc
      rpt[:priority] = File.basename(filename).split("_").first.to_i
      # rec = self.find_by_name_and_rpt_group(rpt[:name], rpt[:rpt_group])
      # rec = self.find_by_name_and_filename(rpt[:name], rpt[:filename])
      rpt[:template_type] = typ
      rec = self.find_by_filename(rpt[:filename])

      if rec
        if rec.filename && (rec.file_mtime.nil? || rec.file_mtime.utc < rpt[:file_mtime])
          $log.info("MIQ(MiqReport.sync_from_file) #{typ.titleize}: [#{rec.name}] file has been updated on disk, synchronizing with model")
          rec.update_attributes(rpt)
          rec.save
        end
      else
        $log.info("MIQ(MiqReport.sync_from_file) #{typ.titleize}: [#{rpt[:name]}] file has been added to disk, adding to model")
        self.create(rpt)
      end
    end

  end
end
