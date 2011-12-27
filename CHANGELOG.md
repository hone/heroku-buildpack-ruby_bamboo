## v7 (12/27/2011)

Features:

* Upgrade New Relic RPM agent to 3.3.1

## v6 (12/20/2011)

Bugfixes:

* make sure `.bundle/config` exists before reading it

## v5 (12/20/2011) [failed]

Features:

* set bundle frozen for windows

## v4 (11/23/2011)

Bugfixes:

* cd into the right path for bundle binary detection

## v3 (11/22/2011) [failed]

Bugfixes:

* detect the binary is in the bundle before using bundle exec

## v2 (11/22/2011) [failed]

Features:

* bundle exec web process

Bugfixes:

* use newrelic rpm 3.1.2 for ruby 1.8.6 (aspen)
* add detect method so BUILDPACK_URL works again

## v1 (11/11/2011)

Features:

* upgrade newrelic rpm to 3.3.0

Bugfixes:

* bundle exec workers
