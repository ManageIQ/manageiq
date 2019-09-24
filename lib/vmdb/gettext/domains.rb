require 'fast_gettext'

module Vmdb
  module Gettext
    module Domains
      TEXT_DOMAIN ||= 'manageiq'.freeze

      def self.domains
        @domains ||= []
        @domains
      end

      def self.paths
        @paths ||= []
        @paths
      end

      def self.add_domain(name, path, type = :po)
        domains << FastGettext::TranslationRepository.build(name, :path           => path,
                                                                  :type           => type,
                                                                  :report_warning => false)
        paths << path
      end

      def self.initialize_chain_repo
        FastGettext.translation_repositories[TEXT_DOMAIN] =
          FastGettext.add_text_domain(TEXT_DOMAIN, :type => :chain, :chain => @domains)
      end

      def self.reload
        FastGettext.translation_repositories[TEXT_DOMAIN].reload
      end
    end
  end
end
