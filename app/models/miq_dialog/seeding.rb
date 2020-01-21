class MiqDialog
  module Seeding
    extend ActiveSupport::Concern

    DIALOG_DIR = Rails.root.join("product/dialogs/miq_dialogs")

    module ClassMethods
      def seed
        transaction do
          dialogs = where(:default => true).index_by(&:filename)

          seed_files.each do |f|
            seed_record(f, dialogs.delete(seed_filename(f)))
          end

          if dialogs.any?
            _log.info("Deleting the following default MiqDialog(s) as they no longer exist: #{dialogs.keys.sort.collect(&:inspect).join(", ")}")
            MiqDialog.delete(dialogs.values.map(&:id))
          end
        end
      end

      # Used for seeding a specific dialog for test purposes
      def seed_dialog(path)
        seed_record(path, MiqDialog.find_by(:filename => seed_filename(path)))
      end

      private

      def seed_record(path, dialog)
        dialog ||= MiqDialog.new

        # DB and filesystem have different precision so calling round is done in
        # order to eliminate the second fractions diff otherwise the comparison
        # of the file time and the dialog time from db will always be different.
        mtime = File.mtime(path).utc.round
        dialog.file_mtime = mtime

        if dialog.new_record? || dialog.changed?
          filename = seed_filename(path)

          _log.info("#{dialog.new_record? ? "Creating" : "Updating"} MiqDialog #{filename.inspect}")

          attrs = YAML.load_file(path)
          attrs[:filename]   = filename
          attrs[:file_mtime] = mtime
          attrs[:default]    = true

          dialog.update!(attrs)
        end
      end

      def seed_files
        Dir.glob(DIALOG_DIR.join("*.{yml,yaml}")).sort + seed_plugin_files
      end

      def seed_plugin_files
        Vmdb::Plugins.flat_map do |plugin|
          Dir.glob(plugin.root.join("content/miq_dialogs/*.{yml,yaml}")).sort
        end
      end

      def seed_filename(path)
        File.basename(path)
      end
    end
  end
end
