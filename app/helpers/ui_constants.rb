module UiConstants
  # Session data size logging constants
  case Rails.env
  when "test"
    SESSION_LOG_THRESHOLD = 50.kilobytes
    SESSION_ELEMENT_THRESHOLD = 5.kilobytes
  when "development"
    SESSION_LOG_THRESHOLD = 50.kilobytes
    SESSION_ELEMENT_THRESHOLD = 5.kilobytes
  else
    SESSION_LOG_THRESHOLD = 100.kilobytes
    SESSION_ELEMENT_THRESHOLD = 10.kilobytes
  end

  # MAX_NAME_LEN = 20      # Default maximum name length
  # MAX_DESC_LEN = 50      # Default maximum description length
  # MAX_HOSTNAME_LEN = 50  # Default maximum host name length
  # dac - Changed to allow up to 255 characters for all text fields on 1/11/07
  MAX_NAME_LEN = 255        # Default maximum name length
  MAX_DESC_LEN = 255        # Default maximum description length
  MAX_HOSTNAME_LEN = 255    # Default maximum host name length

  MAX_DASHBOARD_COUNT = 10  # Default maximum count of Dashboard per group

  REPORTS_FOLDER = File.join(Rails.root, "product/reports")
  VIEWS_FOLDER = File.join(Rails.root, "product/views")
  CHARGEBACK_REPORTS_FOLDER = File.join(Rails.root, "product/chargeback/miq_reports")
  OPS_REPORTS_FOLDER = File.join(Rails.root, "product/ops/miq_reports")
  CHARTS_REPORTS_FOLDER = File.join(Rails.root, "product/charts/miq_reports")
  CHARTS_LAYOUTS_FOLDER = File.join(Rails.root, "product/charts/layouts")
  TIMELINES_FOLDER = File.join(Rails.root, "product/timelines")
  TOOLBARS_FOLDER = File.join(Rails.root, "product/toolbars")
  USAGE_REPORTS_FOLDER = File.join(Rails.root, "product/usage/miq_reports")

  TOP_TABLES_BY_ROWS_COUNT = 5
  TOP_TABLES_BY_SIZE_COUNT = 5
  TOP_TABLES_BY_WASTED_SPACE_COUNT = 5
  GIGABYTE = 1024 * 1024 * 1024

  # VMware MKS version choices
  MKS_VERSIONS = ["2.0.1.0", "2.0.2.0", "2.1.0.0"]

  # PDF page sizes
  PDF_PAGE_SIZES = {
    "a0"            => _("A0 - 841mm x 1189mm"),
    "a1"            => _("A1 - 594mm x 841mm"),
    "a2"            => _("A2 - 420mm x 594mm"),
    "a3"            => _("A3 - 297mm x 420mm"),
    "a4"            => _("A4 - 210mm x 297mm (default)"),
    "US-Letter"     => _("US Letter - 8.5in x 11.0in"),
    "US-Legal"      => _("US Legal - 8.5in x 14.0in"),
    "US-Executive"  => _("US Executive - 7.25in x 10.5in"),
    "US-Ledger"     => _("US Ledger - 17.0in x 11.0in"),
    "US-Tabloid"    => _("US Tabloid - 11.0in x 17.0in"),
    "US-Government" => _("US Government - 8.0in x 11.0in"),
    "US-Statement"  => _("US Statement - 5.5in x 8.5in"),
    "US-Folio"      => _("US Folio - 8.5in x 13.0in")
  }
  DEFAULT_PDF_PAGE_SIZE = "US-Letter"

  # Per page choices and default
  PPCHOICES = [
    [5, 5],
    [10, 10],
    [20, 20],
    [50, 50],
    [100, 100],
    [200, 200],
    [500, 500],
    [1000, 1000]
  ]

  # Per page choices for task/jobs
  PPCHOICES2 = [
    [5, 5],
    [10, 10],
    [20, 20],
    [50, 50],
    [100, 100],
  ]

  # Setting high number incase we don't want to display paging controls on list views
  ONE_MILLION = 1000000

  # RSS Feeds
  RSS_FEEDS = {
    "Microsoft Security"         => "http://www.microsoft.com/protect/rss/rssfeed.aspx",
    "CNN Top Stories"            => "http://rss.cnn.com/rss/cnn_topstories.rss",
    "Gartner Latest Research"    => "http://www.gartner.com/it/rss/leaders/latest_research_itoperations.jsp#",
    "Google News"                => "http://news.google.com/?output=rss",
    "SlashDot"                   => "http://slashdot.org/index.rdf",
    "VM Etc."                    => "http://feeds.feedburner.com/vmetc?format=xml",
    "Virtualization Pro"         => "http://itknowledgeexchange.techtarget.com/virtualization-pro/feed/",
    "Virtualization Information" => "http://virtualizationinformation.com/?feed=rss2",
    "Vmware Tips & Tricks"       => "http://rss.techtarget.com/840.xml",
    "DABCC - News & Support"     => "http://feeds.dabcc.com/AllArticles",
    "VmwareWolf"                 => "http://feeds.feedburner.com/vmwarewolf",
    "Vmware RSS Feeds"           => "http://vmware.simplefeed.net/rss?f=995b0290-01dc-11dc-3032-0019bbc54f6f"
  }

  # UI Themes
  THEMES =  [
    [_("Red"), "red"],
    [_("Orange"), "orange"],
    [_("Yellow"), "yellow"],
    [_("Green"), "green"],
    [_("Blue"), "blue"],
    [_("ManageIQ-Blue"), "manageiq-blue"],
    [_("Black"), "black"]
  ]

  # Screen background color choices
  BG_COLORS = [
    "#c00",      # First entry is the default
    "#ff8a00",
    "#ffe400",
    "#6b9130",
    "#0c7ad7",
    "#000"
  ]

  # Navigation Styles
  NAV_STYLES = [
    "vertical",     # First entry is the default
    "wedged"
  ]

  # Theme settings - each subitem will be set in @settings[:css][:<subitem>] based on the selected theme
  THEME_CSS_SETTINGS = {
    "red"           => {
      :font_color       => "#c00",
      :background_color => "#c00"
    },
    "orange"        => {
      :font_color       => "#ff8a00",
      :background_color => "#ff8a00"
    },
    "yellow"        => {
      :font_color       => "#ffe400",
      :background_color => "#ffe400"
    },
    "green"         => {
      :font_color       => "#6b9130",
      :background_color => "#6b9130"
    },
    "blue"          => {
      :font_color       => "#0c7ad7",
      :background_color => "#0c7ad7"
    },
    "manageiq-blue" => {
      :font_color       => "#0c7ad7",
      :background_color => "#187aa2"
    },
    "black"         => {
      :font_color       => "#000",
      :background_color => "#000"
    }
  }

  PERPAGE_TYPES = %w(grid tile list reports).each_with_object({}) { |value, acc| acc[value] = value.to_sym }.freeze

  # Default UI settings
  DEFAULT_SETTINGS = {
    :quadicons => { # Show quad icons, by resource type
      :service      => true,
      :ems          => true,
      :ems_cloud    => true,
      :host         => true,
      :miq_template => true,
      :storage      => true,
      :vm           => true
    },
    :views     => { # List view setting, by resource type
      :authkeypaircloud                         => "list",
      :availabilityzone                         => "list",
      :catalog                                  => "list",
      :cm_providers                             => "list",
      :cm_configured_systems                    => "list",
      :compare                                  => "expanded",
      :compare_mode                             => "details",
      :condition                                => "list",
      :container                                => "list",
      :containergroup                           => "list",
      :containernode                            => "list",
      :containerservice                         => "list",
      :containerroute                           => "list",
      :containerproject                         => "list",
      :containerimage                           => "list",
      :containerimageregistry                   => "list",
      :persistentvolume                         => "list",
      :cimbasestorageextent                     => "list",
      :cimstorageextent                         => "list",
      :cloudtenant                              => "list",
      :cloudvolume                              => "list",
      :cloudvolumesnapshot                      => "list",
      :drift                                    => "expanded",
      :drift_mode                               => "details",
      :emscluster                               => "grid",
      :emscloud                                 => "grid",
      :emsinfra                                 => "grid",
      :emscontainer                             => "grid",
      :filesystem                               => "list",
      :flavor                                   => "list",
      :host                                     => "grid",
      :job                                      => "list",
      :manageiq_providers_cloudmanager          => "grid",
      :manageiq_providers_cloudmanager_template => "list",
      :manageiq_providers_cloudmanager_vm       => "grid",
      :manageiq_providers_containermanager      => "grid",
      :manageiq_providers_inframanager          => "grid",
      :manageiq_providers_inframanager_vm       => "grid",
      :manageiq_providers_inframanager_template => "list",
      :miqaction                                => "list",
      :miqaeclass                               => "list",
      :miqaeinstance                            => "list",
      :miqevent                                 => "list",
      :miqpolicy                                => "list",
      :miqpolicyset                             => "list",
      :miqreportresult                          => "list",
      :miqrequest                               => "list",
      :miqtemplate                              => "list",
      :ontapfileshare                           => "list",
      :ontaplogicaldisk                         => "list",
      :ontapstoragesystem                       => "list",
      :ontapstoragevolume                       => "list",
      :orchestrationstack                       => "list",
      :orchestrationtemplate                    => "list",
      :servicetemplate                          => "list",
      :storagemanager                           => "list",
      :miqtask                                  => "list",
      :ms                                       => "grid",
      :policy                                   => "list",
      :policyset                                => "grid",
      :resourcepool                             => "grid",
      :service                                  => "grid",
      :scanhistory                              => "list",
      :snialocalfilesystem                      => "list",
      :storage_files                            => "list",
      :registryitems                            => "list",
      :repository                               => "grid",
      :serverbuild                              => "list",
      :storage                                  => "grid",
      :tagging                                  => "grid",
      :treesize                                 => "20",
      :vm                                       => "grid",
      :vmcloud                                  => "grid",
      :vmortemplate                             => "grid",
      :vmcompare                                => "compressed",
      :vminfra                                  => "grid"
    },
    :perpage   => { # Items per page, by view setting
      :grid    => 20,
      :tile    => 20,
      :list    => 20,
      :reports => 20
    },
    :display   => {
      :startpage     => "/dashboard/show",
      :reporttheme   => "MIQ",
      :quad_truncate => "m",
      :theme         => "red",            # Luminescent Blue
      :bg_color      => BG_COLORS.first,  # Background color
      :taskbartext   => true,             # Show button text on taskbar
      :vmcompare     => "Compressed",     # Start VM compare and drift in compressed mode
      :hostcompare   => "Compressed",     # Start Host compare in compressed mode
      :nav_style     => NAV_STYLES.first,  # Navigation style
      :timezone      => nil               # This will be set when the user logs in
    },
    # Commented in sprint 67 - new widget based dashboards
    #    :dashboard => {
    #      :col_1   =>  ["rss1", "chart1"],               # Column 1 contents
    #      :col_2   =>  ["chart2", "rss2"],               # Column 2 contents
    #      :col_3   =>  ["report1", "report2", "rss3"],   # Column 3 contents
    #      :rssshow =>  false,                            # Show external rss feed
    #      :rssfeed =>  "Microsoft Security"              # External rss feed choice
    #    },
    #    :db_item_min => Hash.new # Start with blank hash to hold dashboard item minimized flags
  }

  VIEW_RESOURCES = DEFAULT_SETTINGS[:views].keys.each_with_object({}) { |value, acc| acc[value.to_s] = value }.freeze

  TIMER_DAYS = [
    [_("Day"), "1"],
    [_("2 Days"), "2"],
    [_("3 Days"), "3"],
    [_("4 Days"), "4"],
    [_("5 Days"), "5"],
    [_("6 Days"), "6"],
  ]
  TIMER_HOURS = [
    [_("Hour"), "1"],
    [_("2 Hours"), "2"],
    [_("3 Hours"), "3"],
    [_("4 Hours"), "4"],
    [_("6 Hours"), "6"],
    [_("8 Hours"), "8"],
    [_("12 Hours"), "12"],
  ]
  TIMER_WEEKS = [
    [_("Week"), "1"],
    [_("2 Weeks"), "2"],
    [_("3 Weeks"), "3"],
    [_("4 Weeks"), "4"],
  ]
  TIMER_MONTHS = [
    [_("Month"), "1"],
    [_("2 Months"), "2"],
    [_("3 Months"), "3"],
    [_("4 Months"), "4"],
    [_("5 Months"), "5"],
    [_("6 Months"), "6"],
  ]

  # Maximum fields to show for automation engine resolution screens
  AE_MAX_RESOLUTION_FIELDS = 5

  DRIFT_TIME_COLUMNS = [
    "last_scan_on",
    "boot_time",
    "last_logon"
  ]
  # START of TIMELINE TIMEZONE Code
  TIMELINE_TIME_COLUMNS = [
    "created_on",
    "timestamp"
  ]
  # END of TIMELINE TIMEZONE Code

  # Choices for trend and C&U days back pulldowns
  WEEK_CHOICES = {
    7  => _("1 Week"),
    14 => _("2 Weeks"),
    21 => _("3 Weeks"),
    28 => _("4 Weeks")
    # 60 => "2 Months",   # Removed longer times when on demand daily rollups was added in sprint 59 due to performance
    # 90 => "3 Months",
    # 180 => "6 Months"
  }

  # Choices for C&U last hour real time minutes back pulldown
  REALTIME_CHOICES = {
    10.minutes => _("10 Minutes"),
    15.minutes => _("15 Minutes"),
    30.minutes => _("30 Minutes"),
    45.minutes => _("45 Minutes"),
    1.hour     => _("1 Hour")
  }

  # Choices for Target options show pulldown
  TARGET_TYPE_CHOICES = {
    "EmsCluster" => _("Clusters"),
    "Host"       => _("Hosts")
  }

  # Choices for the trend limit percent pulldowns
  TREND_LIMIT_PERCENTS = {
    "200%" => 200,
    "190%" => 190,
    "180%" => 180,
    "170%" => 170,
    "160%" => 160,
    "150%" => 150,
    "140%" => 140,
    "130%" => 130,
    "120%" => 120,
    "110%" => 110,
    "100%" => 100,
    "95%"  => 95,
    "90%"  => 90,
    "85%"  => 85,
    "80%"  => 80,
    "75%"  => 75,
    "70%"  => 70,
    "65%"  => 65,
    "60%"  => 60,
    "55%"  => 55,
    "50%"  => 50,
  }

  # Report Controller constants
  NOTHING_STRING = "<<< Nothing >>>"
  SHOWALL_STRING = "<<< Show All >>>"
  MAX_REPORT_COLUMNS = 100      # Default maximum number of columns in a report
  BAND_UNITS = ["Second", "Minute", "Hour", "Day", "Week", "Month", "Year", "Decade"]
  GRAPH_MAX_COUNT = 10

  TREND_MODEL = "VimPerformanceTrend"   # Performance trend model name requiring special processing

  # Source pulldown in VM Options
  PLANNING_VM_MODES = {
    :allocated => _("Allocation"),
    :reserved  => _("Reservation"),
    :used      => _("Usage"),
    :manual    => _("Manual Input")
  }
  VALID_PLANNING_VM_MODES = PLANNING_VM_MODES.keys.index_by(&:to_s)

  TASK_TIME_PERIODS = {
    0 => _("Today"),
    1 => _("1 Day Ago"),
    2 => _("2 Days Ago"),
    3 => _("3 Days Ago"),
    4 => _("4 Days Ago"),
    5 => _("5 Days Ago"),
    6 => _("6 Days Ago")
  }
  SP_STATES = [[_("Initializing"), "initializing"], [_("Waiting to Start"), "waiting_to_start"],
               [_("Cancelling"), "cancelling"], [_("Aborting"), "aborting"], [_("Finished"), "finished"],
               [_("Snapshot Create"), "snapshot_create"], [_("Scanning"), "scanning"],
               [_("Snapshot Delete"), "snapshot_delete"], [_("Synchronizing"), "synchronizing"],
               [_("Deploy Smartproxy"), "deploy_smartproxy"]].freeze
  UI_STATES = [[_("Initialized"), "Initialized"], [_("Queued"), "Queued"], [_("Active"), "Active"],
               [_("Finished"), "Finished"]].freeze

  PROV_STATES = {
    "pending_approval" => _("Pending Approval"),
    "approved"         => _("Approved"),
    "denied"           => _("Denied")
  }
  PROV_TIME_PERIODS = {
    1  => _("Last 24 Hours"),
    7  => _("Last 7 Days"),
    30 => _("Last 30 Days")
  }

  ALL_TIMEZONES = ActiveSupport::TimeZone.all.collect { |tz| ["(GMT#{tz.formatted_offset}) #{tz.name}", tz.name] }
  # Following line does not include timezones with partial hour offsets
  # ALL_TIMEZONES = ActiveSupport::TimeZone.all.collect{|tz| tz.utc_offset % 3600 == 0 ? ["(GMT#{tz.formatted_offset}) #{tz.name}",tz.name] : nil}.compact

  CATEGORY_CHOICES = {}
  CATEGORY_CHOICES["services"] = _("Services")
  CATEGORY_CHOICES["software"] = _("Software")
  CATEGORY_CHOICES["system"] = _("System")
  CATEGORY_CHOICES["accounts"] = _("User Accounts")
  CATEGORY_CHOICES["vmconfig"] = _("VM Configuration")
  # CATEGORY_CHOICES["vmevents"] = "VM Events"

  # Assignment choices
  ASSIGN_TOS = {}

  # This set of assignments was created for miq_alerts
  ASSIGN_TOS["ExtManagementSystem"] = {
    "enterprise"                 => _("The Enterprise"),
    "ext_management_system"      => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "ems_infra")},
    "ext_management_system-tags" => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "ems_infra")}
  }
  ASSIGN_TOS["EmsCluster"] = {
    "ems_cluster"      => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "ems_cluster")},
    "ems_cluster-tags" => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "ems_cluster")}
  }.merge(ASSIGN_TOS["ExtManagementSystem"])
  ASSIGN_TOS["Host"] = {
    "host"      => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "host")},
    "host-tags" => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "host")}
  }.merge(ASSIGN_TOS["EmsCluster"])
  ASSIGN_TOS["Vm"] = {
    "ems_folder"         => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "ems_folder")},
    "resource_pool"      => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "resource_pool")},
    "resource_pool-tags" => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "resource_pool")},
    "vm-tags"            => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "vm")}
  }.merge(ASSIGN_TOS["Host"])
  ASSIGN_TOS["Storage"] = {
    "enterprise"   => _("The Enterprise"),
    "storage"      => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "storage")},
    "storage-tags" => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "storage")},
    "tenant"       => _("Tenant")
  }
  ASSIGN_TOS["MiqServer"] = {
    "miq_server" => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "miq_server")},
  }

  # This set of assignments was created for chargeback_rates
  ASSIGN_TOS[:chargeback_storage] = ASSIGN_TOS["Storage"]
  ASSIGN_TOS[:chargeback_compute] = {
    "enterprise"            => _("The Enterprise"),
    "ext_management_system" => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "ext_management_systems")},
    "ems_cluster"           => _("Selected %{tables}") % {:tables => ui_lookup(:tables => "ems_cluster")},
    "vm-tags"               => _("Tagged %{tables}") % {:tables => ui_lookup(:tables => "vm")},
    "tenant"		     => _("Tenant")
  }

  EXP_COUNT_TYPE = [_("Count of"), "count"].freeze  # Selection for count based filters
  EXP_FIND_TYPE = [_("Find"), "find"].freeze        # Selection for find/check filters
  EXP_TYPES = [                           # All normal filters
    [_("Field"), "field"],
    EXP_COUNT_TYPE,
    [_("Tag"), "tag"],
    EXP_FIND_TYPE
  ]
  VM_EXP_TYPES = [                        # Special VM registry filter
    [_("Registry"), "regkey"]
  ]

  # Snapshot ages for delete_snapshots_by_age action type
  SNAPSHOT_AGES = {}
  (1..23).each { |a| SNAPSHOT_AGES[a.hours.to_i] = (a.to_s + (a < 2 ? _(" Hour") : _(" Hours"))) }
  (1..6).each { |a| SNAPSHOT_AGES[a.days.to_i] = (a.to_s + (a < 2 ? _(" Day") : _(" Days"))) }
  (1..4).each { |a| SNAPSHOT_AGES[a.weeks.to_i] = (a.to_s + (a < 2 ? _(" Week") : _(" Weeks"))) }

  # Expression constants
  EXP_TODAY = "Today"
  EXP_FROM = "FROM"
  EXP_IS = "IS"

  # FROM Date/Time expression atom selectors
  FROM_HOURS = [
    _("This Hour"),
    _("Last Hour"),
  ] + Array.new(22) { |i| _("%{number} Hours Ago") % {:number => i + 2} }
  FROM_DAYS = [
    _("Today"),
    _("Yesterday"),
    _("2 Days Ago"),
    _("3 Days Ago"),
    _("4 Days Ago"),
    _("5 Days Ago"),
    _("6 Days Ago"),
    _("7 Days Ago"),
    _("14 Days Ago")
  ]
  FROM_WEEKS = [
    _("This Week"),
    _("Last Week"),
    _("2 Weeks Ago"),
    _("3 Weeks Ago"),
    _("4 Weeks Ago")
  ]
  FROM_MONTHS = [
    _("This Month"),
    _("Last Month"),
    _("2 Months Ago"),
    _("3 Months Ago"),
    _("4 Months Ago"),
    _("6 Months Ago")
  ]
  FROM_QUARTERS = [
    _("This Quarter"),
    _("Last Quarter"),
    _("2 Quarters Ago"),
    _("3 Quarters Ago"),
    _("4 Quarters Ago")
  ]
  FROM_YEARS = [
    _("This Year"),
    _("Last Year"),
    _("2 Years Ago"),
    _("3 Years Ago"),
    _("4 Years Ago")
  ]

  # Need this for display purpose to map with id
  WIDGET_TYPES = {
    "r"  => _("Reports"),
    "c"  => _("Charts"),
    "rf" => _("RSS Feeds"),
    "m"  => _("Menus")
  }
  # Need this for mapping with MiqWidget record content_type field
  WIDGET_CONTENT_TYPE = {
    "r"  => "report",
    "c"  => "chart",
    "rf" => "rss",
    "m"  => "menu"
  }

  VALID_PERF_PARENTS = {
    "EmsCluster" => :ems_cluster,
    "Host"       => :host
  }

  MIQ_AE_COPY_ACTIONS = %w(miq_ae_class_copy miq_ae_instance_copy miq_ae_method_copy)

  AVAILABLE_CONFIG_NAMES = {
    # First name includes space so it is first in UI select box
    "vmdb"                     => _(" EVM Server Main Configuration"),
    "event_handling"           => _("Event Handler Configuration"),
    "broker_notify_properties" => _("EVM Vim Broker Notification Properties"),
    "capacity"                 => _("EVM Capacity Management Configuration")
  }.freeze
  AVAILABLE_CONFIG_NAMES_FOR_SELECT = AVAILABLE_CONFIG_NAMES.invert.sort.freeze

  UTF_16BE_BOM = [254, 255].freeze
  UTF_16LE_BOM = [255, 254].freeze
end

# Make these constants globally available
include UiConstants
