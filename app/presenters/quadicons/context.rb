module Quadicons
  # The context in which quadicons are rendered
  # This is a kind of adapter between global view state
  # and quadicon rendering
  #
  class Context
    attr_reader :template

    attr_accessor :controller, :edit, :embedded, :explorer,
                  :lastaction, :listicon, :listnav,
                  :parent, :policies, :policy_sim,
                  :settings, :showlinks, :view

    delegate  :content_tag, :image_tag, :concat, :link_to, :role_allows?,
              :url_for, :to => :template

    def initialize(template)
      @template = template

      yield self if block_given?
    end

    # Define this here rather than delegate as a place to
    # handle different url generators, but for now ...
    def url_for_record(record, action = nil)
      # Work around dependence on @explorer in ApplicationHelper#db_to_controller
      action ||= in_explorer_view? ? "x_show" : "show"
      template.url_for_record(record, action)
    end

    def truncate_mode
      settings.fetch_path(:display, :quad_truncate) || 'm'
    end

    def listicon_nil?
      listicon.nil?
    end

    def in_embedded_view?
      !!embedded
    end

    def show_link_ivar?
      !!showlinks
    end

    def hide_links?
      !show_links?
    end

    def show_links?
      !in_embedded_view? || show_link_ivar?
    end

    # TODO: Combine this with above
    def render_link?
      listnav.nil? || !(!!listnav)
    end

    def policy_sim?
      !!policy_sim
    end

    def lastaction_is_policy_sim?
      lastaction == "policy_sim"
    end

    def in_explorer_view?
      !!explorer
    end

    def policies_are_set?
      !policies.empty?
    end

    def in_service_controller?
      controller == "service"
    end

    def view_db_is_vm?
      view.db == "Vm"
    end

    def service_ctrlr_and_vm_view_db?
      in_service_controller? && view_db_is_vm?
    end

    def render_for_policy_sim?
      policy_sim? && policies_are_set?
    end

    def edit_key?(key)
      !!(edit && edit[key])
    end

    # formerly session[:policies].keys
    def policy_keys
      policies ? policies.keys : []
    end

    def fetch_settings(*path)
      if path.any?
        settings && settings.fetch_path(*path)
      end
    end
  end
end
