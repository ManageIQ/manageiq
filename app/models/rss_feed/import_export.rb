class RssFeed
  module ImportExport
    extend ActiveSupport::Concern

    def export_to_array
      h = attributes
      ["id", "created_on", "updated_on", "yml_file_mtime"].each { |k| h.delete(k) }
      [self.class.to_s => h]
    end
  end
end
