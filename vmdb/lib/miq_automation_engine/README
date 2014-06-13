Engine Description:

There are two types of storage for the Automation Engine:

The Automation Datastore is the persistent storage and it can be viewed/edited by the EVM Automate Object Explorer.  The data lives in SQL Tables beginning with miq_ae: miq_ae_namespaces, miq_ae_classes, miq_ae_fields, miq_ae_values, miq_ae_instances, miq_ae_methods.
The Automation Workspace is the transient storage of the in-memory object hierarchy.  There is a SQL Table called miq_ae_workspaces, but it is not currently leveraged and can be ignored for now.

Each Automation Engine invocation runs in an isolated Workspace.

Automate Engine is invoked with a URI and leverages URIs throughout.  So, a solid understandings of URIs is a must.  A URI stands for Uniform Resource Identifier and can be read about here http://en.wikipedia.org/wiki/Uniform_Resource_Identifier and http://tools.ietf.org/html/rfc3986.

Here is a grammar for a URI:

     URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]

     hier-part   = "//" authority path-abempty
                 / path-absolute
                 / path-rootless
                 / path-empty


Here is a typical example:

  foo://example.com:8042/over/there?name=ferret#nose
  \_/   \______________/\_________/ \_________/ \__/
   |           |            |            |        |
scheme     authority       path        query   fragment


The Automation Engine supports two schemes (currently):

miqaedb => get an object from the Automation Datastore
miqaews => get an object from the Automation Workspace



Database Layout:

  MIQ_AE_NAMESPACES Table (each row defines a NAMESPACE in the system)
    id            ==> ID           of the Namespace
    parent_id     ==> ID           of the parent Namespace (NULL if root)
    display_name  ==> Display Name of the Namespace
    description   ==> Description  of the Namespace
    name          ==> Name         of the Namespace
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

  MIQ_AE_CLASSES Table (each row defines a CLASS in the system)
    id            ==> ID           of the Class
    display_name  ==> Display Name of the Class
    description   ==> Description  of the Class
    namespace_id  ==> ID           of the Namespace
    name          ==> Name         of the Class
    type          ==> Type         of the Class (abstract ==> No Instances Allowed, ...)
    inherits      ==> Name         of the Inherited Class (NULL if no inheritance)
    visibility    ==> Private ==> only visible within Resolution; Public ==> accessible to caller of Resolution
    owner         ==> Owner        of the Class
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

  MIQ_AE_FIELDS Table (each row defines a FIELD in the system)
    id            ==> ID           of the Field
    name          ==> Name         of the Field
    display_name  ==> Display Name of the Field
    description   ==> Description  of the Field
    aetype        ==> AE Type      of the Field      (assertion, attribute, relationship, method, state)
    datatype      ==> Type         of the Field Data (string, integer, boolean, ...)
    priority      ==> Order        of the Field      (within the Class)
    owner         ==> Owner        of the Field
    scope         ==> Scope        of the Field
    default_value ==> Default      of the Field      (the default value)
    substitute    ==> Substitution Enabled?
    message       ==> Message   that this Field responds to
    visibility    ==> Private ==> only visible within Resolution; Public ==> accessible to caller of Resolution
    collect       ==> Collection/Aggregation definition
    condition     ==> Condition (IF/UNLESS) that indicates whether to process
    class_id      ==> ID           of the Class  that this Field belongs to
    method_id     ==> ID           of the Method that this Field belongs to
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

  MIQ_AE_INSTANCES Table (each row defines an INSTANCE of a specific class)
    id            ==> ID           of the Instance
    name          ==> Name         of the Instance
    display_name  ==> Display Name of the Instance
    description   ==> Description  of the Instance
    class_id      ==> ID           of the Class  that this Instance belongs to
    inherits      ==> Name         of the Inherited Class (NULL if no inheritance)
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

  MIQ_AE_VALUES Table (each row defines a VALUE of a specific field in a specific instance)
    id            ==> ID           of the Value
    display_name  ==> Display Name of the Value
    value         ==> VALUE        of the Value
    instance_id   ==> ID           of the Instance
    field_id      ==> ID           of the Field
    collect       ==> Collection/Aggregation definition
    condition     ==> Condition (IF/UNLESS) that indicates whether to process
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

  MIQ_AE_WORKSPACES Table (keeps instantiated trees)
    id            ==> ID           of the Workspace
    guid          ==> GUID         of the Workspace
    uri           ==> URI          of the Workspace
    workspace     ==> Binary representation of the Workspace
    setters       ==> Binary representation of attributes overridden externally
    created_on    ==> ctime (Creation     Timestamp)
    updated_on    ==> mtime (Modification Timestamp)

Dynamic Instantion Process (AE_DIP)

===================

Add display_name for namespace and value (for STEP field and completeness)
Add condition for field and value (IF/UNLESS)
Add collect for value (overrides definition in FIELD)
Define new type of field called STEP
AE_DIP should process steps as follows:
  1. Should convert steps to relationships appending #${#ae_message}
  2. Dynamically call methods before_step and after_step (or on_state_change)
  3. Should roughly internalize working of provision_state_machine to allow for others to be defined easier
