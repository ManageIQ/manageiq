class RssFeed
  module ImportExport
    extend ActiveSupport::Concern

    module ClassMethods
      def import_from_hash(rss, options = {})
        raise _("No RssFeed to Import") if rss.nil?

        rss = rss["RssFeed"] if rss.keys.first == "RssFeed"

        user = User.find_by_userid(options[:userid])

        rf = RssFeed.find_by_name(rss["name"])
        if rf.nil?
          # create new RssFeed
          msg = "Importing RssFeed: [#{rss["name"]}]"
          rf = RssFeed.new(rss)
          result = {:message => _("Importing RssFeed: [%{name}]") % {:name => rss["name"]},
                    :level   => :info,
                    :status  => :add}
        elsif !options[:overwrite]
          # if RssFeed exists dont overwrite
          msg = "Skipping RssFeed (already in DB): [#{rss["name"]}]"
          result = {:message => _("Skipping RssFeed (already in DB): [%{name}]") % {:name => rss["name"]},
                    :level   => :info,
                    :status  => :keep}
        elsif user.admin_user?
          # if RssFeed exists delete and create new
          msg = "Overwriting RssFeed: [#{rss["name"]}]"
          rf.attributes = rss
          result = {:message => _("Replaced RssFeed: [%{name}]") % {:name => rss["name"]},
                    :level   => :info,
                    :status  => :update}
        else
          # if RssFeed exists dont overwrite
          msg = "Skipping RssFeed (already in DB under a different group): [#{rss["name"]}]"
          result = {:message => _("Skipping RssFeed (already in DB under a different group): [%{name}]") %
                                  {:name => rss["name"]},
                    :level   => :error,
                    :status  => :skip}
        end
        _log.info("#{msg}")

        if options[:save] && result[:status].in?([:add, :update])
          rf.save!
          _log.info("- Completed.")
        end

        return rf, result
      end
    end

    def export_to_array
      h = attributes
      ["id", "created_on", "updated_on", "yml_file_mtime"].each { |k| h.delete(k) }
      [self.class.to_s => h]
    end
  end
end
