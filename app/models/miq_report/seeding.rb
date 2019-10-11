module MiqReport::Seeding
  extend ActiveSupport::Concern

  REPORT_DIR  = Rails.root.join("product", "reports").freeze
  COMPARE_DIR = Rails.root.join("product", "compare").freeze

  module ClassMethods
    def seed
      transaction do
        reports = where(:rpt_type => 'Default').where.not(:filename => nil).index_by do |f|
          seed_filename(f.filename)
        end
        # seeding from files, :filename attribute of existing record may be changed in this process
        seed_files.each do |f|
          seed_record(f, reports[seed_filename(f)])
        end

        # now remove Default reports which are not supplied as yaml anymore
        reports = where(:rpt_type => 'Default').where.not(:filename => nil).index_by do |f|
          seed_filename(f.filename)
        end
        seed_files.each do |f|
          reports.delete(seed_filename(f))
        end
        if reports.any?
          _log.info("Deleting the following MiqReport(s) as they no longer exist: #{reports.keys.sort.collect(&:inspect).join(", ")}")

          # TODO: Can we make this a delete by getting rid of the dependent destroy on miq_report_result and using the purger?
          MiqReport.destroy(reports.values.map(&:id))
        end
      end
    end

    # Used for seeding a specific report for test purposes
    def seed_report(name)
      path = seed_files.detect { |f| File.basename(f).include?(name) }
      raise "report #{name.inspect} not found" if path.nil?

      seed_record(path, MiqReport.find_by(:filename => seed_filename(path)))
    end

    private

    def seed_record(path, report)
      report ||= MiqReport.new

      # DB and filesystem have different precision so calling round is done in
      # order to eliminate the second fractions diff otherwise the comparison
      # of the file time and the report time from db will always be different.
      mtime = File.mtime(path).utc.round
      report.file_mtime = mtime

      if report.new_record? || report.changed?
        filename = seed_filename(path)

        _log.info("#{report.new_record? ? "Creating" : "Updating"} MiqReport #{filename.inspect}")

        yml  = YAML.load_file(path).symbolize_keys
        name = yml[:menu_name].strip

        attrs = yml.slice(*column_names_symbols)
        attrs.delete(:id)
        attrs[:filename]      = filename
        attrs[:file_mtime]    = mtime
        attrs[:name]          = name
        attrs[:priority]      = File.basename(path).split("_").first.to_i
        attrs[:rpt_group]     = File.basename(File.dirname(path)).split("_").last
        attrs[:rpt_type]      = "Default"
        attrs[:template_type] = template_type(path)

        begin
          report.update!(attrs)
        rescue ActiveRecord::RecordInvalid
          duplicate = find_by(:name => name)
          if duplicate&.rpt_type == "Custom"
            _log.warn("A custom report already exists with the name #{duplicate.name.inspect}.  Skipping...")
          elsif duplicate
            _log.warn("A default report named '#{duplicate.name.inspect}' loaded from '#{duplicate.filename}' already exists. Updating attributes of existing report...")
            duplicate.update!(attrs)
          else
            raise
          end
        end
      end
    end

    def template_type(path)
      File.dirname(path).include?("reports") ? "report" : "compare"
    end

    def seed_files
      seed_core_files + seed_plugin_files
    end

    def seed_core_files
      [REPORT_DIR, COMPARE_DIR].flat_map { |dir| Dir.glob(dir.join("**", "*.yaml")).sort }
    end

    def seed_plugin_files
      Vmdb::Plugins.flat_map do |plugin|
        %w[reports compare].flat_map { |dir| Dir.glob(plugin.root.join("content", dir, "**", "*.yaml")).sort }
      end
    end

    def seed_filename(path)
      if File.dirname(path).include?("reports")
        path.split("reports/").last
      elsif File.dirname(path).include?("compare")
        path.split("compare/").last
      else
        path
      end
    end
  end
end
