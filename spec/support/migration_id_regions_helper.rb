module Spec
  module Support
    module MigrationIdRegionsHelper
      def anonymous_class_with_id_regions
        ActiveRecord::IdRegions::Migration.anonymous_class_with_id_regions
      end
    end
  end
end
