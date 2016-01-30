
#CloudForms Management Engine REST API Client

Helper library that simplifies access to the CFME REST API.


CFME REST Api returns true or false for success or failure of the Api call.

Then code, status, message and result can be queried via object.

## Sample Usage:

```
require 'cfme_client'

cfme = CfmeClient.new(:url => "http://localhost:3000")

if cfme.authenticate( :user => "admin", :password => "smartvm" )
  auth_token = cfme.result["auth_token"]
else
  puts "Failed to authenticate user - #{cfme.message}
end
```

## Resource Options

```  
[:scheme, :host, :port] or optionally [:url]
```

```
:url => "http://localhost:3000"

    or

:scheme => "http"
:host => "localhost"
:port => 3000

```

Resource options can be specified with any Api call, so the following is also a valid usage:

```
require 'cfme_client'

cfme = CfmeClient.new()

if cfme.authenticate( :url => "http://localhost:3000", :user => "admin", :password => "smartvm" )
  auth_token = cfme.result["auth_token"]
else
  puts "Failed to authenticate user - #{cfme.message}"
end
```

## Authentication Options

```
[:user, :password] pair or [:auth_token]
```

```
:user => "admin"
:password => "smartvm"
```


## Common API Options

|Option|Description|
|------|-----------|
|:version|Specify the Version of the API  i.e.  :version => "1.0"|



