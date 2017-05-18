module MiqReport::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    REPORT_DIR  = File.expand_path(File.join(Rails.root, "product/reports"))
    COMPARE_DIR = File.expand_path(File.join(Rails.root, "product/compare"))

    def seed
      # Force creation of model instances for all report yaml files that exist in the product/reports directories
      # that don't already have an instance in the model
      MiqReport.sync_from_dir("report")
      MiqReport.sync_from_dir("compare")
    end

    def seed_report(pattern, type = "report")
      dir = type == "report" ? REPORT_DIR : COMPARE_DIR
      files = Dir.glob(File.join(dir, "**/*#{pattern}*"))
      files.collect do |f|
        sync_from_file(f, dir, type)
      end
    end

    def sync_from_dir(typ)
      if typ == "report"
        dir = REPORT_DIR
        pattern = "*/*.yaml"
        cond = {:rpt_type => 'Default', :template_type => [typ, nil]}
      else
        dir = COMPARE_DIR
        pattern = "*.yaml"
        cond = {:rpt_type => 'Default', :template_type => typ}
      end

      where(cond).where.not(:filename => nil).each do |f|
        unless File.exist?(File.join(dir, f.filename))
          $log.info("#{typ.titleize}: file [#{f.filename}] has been deleted from disk, deleting from model")
          f.destroy
        end
      end

      Dir.glob(File.join(dir, pattern)).sort.each do |f|
        sync_from_file(f, dir, typ)
      end
    end

    def sync_from_file(filename, dir, typ)
      yml = YAML.load_file(filename)
      rpt = {}
      column_names.each { |c| rpt[c.to_sym] = yml[c] }
      rpt.delete :id
      rpt[:name] = yml["menu_name"].strip
      rpt[:rpt_group] = File.basename(File.dirname(filename)).split("_").last
      rpt[:rpt_type] = "Default"
      rpt[:filename] = filename.sub(dir + "/", "")
      # DB and filesystem have different precision
      # so calling round is done in order to eliminate the second fractions diff
      # otherwise the comparison of the file time and the report time from db
      # will always be different
      rpt[:file_mtime] = File.mtime(filename).utc.round
      rpt[:priority] = File.basename(filename).split("_").first.to_i
      rpt[:template_type] = typ
      rec = find_by_filename(rpt[:filename])

      if rec
        if rec.filename && (rec.file_mtime.nil? || rec.file_mtime.utc < rpt[:file_mtime])
          _log.info("#{typ.titleize}: [#{rec.name}] file has been updated on disk, synchronizing with model")
          rec.update_attributes(rpt)
          rec.save
        end
      else
        _log.info("#{typ.titleize}: [#{rpt[:name]}] file has been added to disk, adding to model")
        create(rpt)
      end
    end
  end
end
