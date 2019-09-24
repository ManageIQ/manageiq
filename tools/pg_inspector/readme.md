pg_inspector readme
===================

pg_inspector is a tool to inspect database locks originating from ManageIQ processes. pg_inpector does this in four steps. Run `pg_inspector.rb -h` to see each of the steps. For each step, see its specific options by running pg_inspector.rb operation `-h`.

Automatically run all steps
---------------------------

Run `schedule_server_dump.sh` to dump server information in a daily basis. Then when a database lock problem happens, run `inspect_pg.sh` to run step 1, 3 and 4 together, and collect all output from `/var/www/miq/vmdb/log/` into `pg_inspector_output.tar.gz`. All the steps below will add `pg_inspector_` prefix for all output file name. For details of each step, see below.

Step 1: dump active connections to YAML file
--------------------------------------------

Run `pg_inspector.rb connections`, and it will dump current `pg_stat_activity` to a YAML file. It will also dump `pg_locks`. The database password should be provided using the file `-f` option or a PGPASSWORD environment variable.

Examples:
```
PGPASSWORD=smartvm pg_inspector.rb connections
pg_inspector.rb connections -u username -f file_that_contains_password -s host -p port -o output_file -l locks_output_file
```

It by default use `root` user to login local postgres server, and will ask you for password. You can connect to a different database host by `-s` option, using a different user by `-u` option, and output to different place by `-o` for active connections, `-l` for locks. But default settings and empty password should be sufficient to run in master node of appliance. This dump operation can be run even after database get blocked.

Step 2: dump ManageIQ server information to YAML file
-----------------------------------------------------

Run `pg_inspector.rb servers` will dump ManageIQ server information in a YAML file. Database password is given in the same way as step 1. New one will overwrite old one only if new one dumps successfully. This step can't be dump if blocking happens, so it should be run as a periodical task.

Examples:
```
PGPASSWORD=smartvm pg_inspector.rb servers
pg_inspector.rb servers -u username -f file_that_contains_password -s host -p port -o output_file
```

Step 3: Combine connections and servers information to human readable format
----------------------------------------------------------------------------

Run `pg_inspector.rb human` will combine information gathered from step 1 and step 2 to a human readable YAML file. It doesn't require database access and will take default output name from step 1 and step 2 as input. It has four sections: servers, workers, connections and other_processes.

Examples:
```
pg_inspector.rb human
pg_inspector.rb human -c connections.yml -s servers.yml -o human.yml
```

Step 4: Combine human.yml file and lock file
--------------------------------------------

Run `pg_inspector.rb locks` will combine lock output from step 1 and human.yml from step 3. It doesn't require database access and will take default output name from step 1 and step 3 as input. The file organization will be same as step 3, but each connection has a `blocked_by` property indicate it's blocked by which connection.

Examples:
```
pg_inspector.rb locks
pg_inspector.rb locks -l locks.yml -c human.yml -o locks_output.yml
```

After four steps
----------------

These four steps are included and can be run in customer's appliance. We can do further analysis such as generating and viewing lock graphs from step 4's output. Because this has external dependency which is not revelant to appliance, it's in a separate place.

