## v12 (12/08/2012)

Bugfixes:

* Security fix, bump New Relic to 3.5.3.25

## v11 (06/21/2012)

Bugfixes:

* hardcode BUNDLE_CONFIG to fix issue since moving to codon

## v10 (05/02/2012)

Bugfixes:

* syck workaround for yaml/psych issues

## v9 (03/26/2012)

* Explicitly set LANG=en_US.UTF-8 before calling Bundler

## v8 (03/20/2012)

* Call Bundler 0.9.9 properly on Aspen

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
