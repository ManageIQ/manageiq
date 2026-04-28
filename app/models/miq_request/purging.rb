class MiqRequest
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.miq_request.history.keep_miq_requests.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.miq_request.history.purge_window_size
      end

      def purge_scope(older_than)
        old_requests = MiqRequest.where(arel_table[:created_on].lt(older_than))

        # Find all MiqRequest subclasses that implement active_provision_requests
        provision_request_types = MiqRequest.descendants.select do |klass|
          klass.respond_to?(:active_provision_requests)
        end

        purgeable_provision_requests = provision_request_types.flat_map do |request_class|
          purgeable_requests_for_class(request_class, older_than)
        end

        old_requests.where.not(:type => provision_request_types.map(&:name))
                    .or(old_requests.where(:id => purgeable_provision_requests))
      end

      def purge_method
        :destroy
      end

      private

      def purgeable_requests_for_class(request_class, older_than)
        old_requests = request_class.where(MiqRequest.arel_table[:created_on].lt(older_than))

        if request_class.respond_to?(:active_provision_requests)
          old_requests.where.not(:id => request_class.active_provision_requests)
        else
          old_requests.select(:id)
        end
      end
    end
  end
end
