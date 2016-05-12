# flapjack-benchmark

Benchmarking tests for Flapjack 

## Overview

The aim of *flapjack-benchmark* is to provide simple benchmarking tools to test against different versions or configurations of Flapjack.

The project uses MiniTest as a mechanism for running tests. This is mostly out of convenience, and doesn't use any assertions or checking features supplied by MiniTest. Neither does it make good use of MiniTest's reporting features, though this may be resolved in the future (see TODO list below).

## Configuring environment

### Prerequisites

The following are required to be installed prior to running the project:

* A Ruby version compatible with both Flapjack 1.6 and 2.0
* Redis version 2.6.12 or greater

The project's `.ruby-version` set Ruby at 2.1.4. Later versions may break Flapjack 1.6, so change this with care.

### flapjack-benchmark.yml

Configuration for *flapjack-benchmark* resides in the `flapjack-benchmark.yml` file located in the application root. An example file is included in the project (`flapjack-benchmark.example.yml`).

A typical configuration (for a local server) looks like this:

```
flapjack_1_6_0:
    redis:
        host: localhost
        port: 6379
        db: 0
    jsonapi:
        base_url: http://localhost
        port: 3082
```

### Appraisals

The project uses ThoughBot's [Appraisal](https://github.com/thoughtbot/appraisal) gem for managing gems related to different versions of Flapjack. To install required gems, and the gems required for different appraisal environments, execute the following:

`bundle install`
`appraisal install`

You may find that the [hiredis](https://github.com/redis/hiredis-rb) gem doesn't install fully. To ensure that native extensions are built you may need to install `hiredis` manually, _e.g._

`bundle exec gem install hiredis -v 0.6.1`

## Test types

### Naive flood

These tests attempt to flood the Flapjack event queue with simple Ping (OK) messages for a non-existent service. There are three different types of tests: (i) ping tests, (ii) equilibrium tests and (iii) peak usage tests.

#### Ping flood tests

The ping tests simply flood the queue with a preset number of events per second - for 40 seconds. Reporting is based on queue length over the sample time, and can vary from 0 (i.e. Flapjack is pulling events off the queue faster than they are being placed) and several thousand events (indicating that Flapjack is struggling to remove events in a timely manner).

The ping tests execute over a range of event rates; from 100 events per sec up to 1000 events per sec.

#### Equilibrium test

The equilibrium test attempt to find a benchmark throughput where events are being pulled off the queue at roughly the same rate as they are being placed on. Equilibrium tests ramp up until the queue length appears stable - specifically when the variance over 50 samples is less than 5 events.

#### Peak usage test

The peak usage test started out as an attempt to develop a more sophisticated equilibrium test, treating events left in the queue as "errors" and modifying the ramp up / down rate (aka gain) accordingly. In practise this doesn't work, as the short periods where the queue gets filled don't give a reasonable error rate, and trying to use an integral value of recent errors doesn't produce a meaningful gain value.

What the test does provide though is an idea of where the system peaks, and can be used to check against the output of the equilibrium (they are usually of similar values). 

In the long term this test should probably be either discarded or rewritten.

### Outage

Outage tests simulate large-scale outages across the services monitored by Flapjack. The tests are intended to (i) determine the baseline for Flapjack's ability to process outage messages and (ii) ensure that delivery of notifications aren't blocked while Flapjack is under load.

Currently only outage flood tests are implemented.

## Running Tests

Flapjack-benchmark leverages off MiniTest. To run all the tests, execute the following:

`bundle exec appraisal [APPRAISAL VERSION] rake test`

where _[APPRAISAL VERSION]_ is the Flapjack version under test. For instance, to test Flapjack 1.6:

`bundle exec appraisal flapjack_1_6 rake test`

Individual test files can executed as per MiniTest's convention, using the TEST variable, _e.g._
 
`bundle exec appraisal flapjack_1_6 rake test TEST=test/naive_flood_test.rb`

## TODO

* Refactor all the `case Flapjack::VERSION` code (use mixins / aliases).
* Create a better reporting mechanism than 'puts' (probably extend the MiniTest reporter model).
* Log test output into a separate file.
* Enable testing of remote Flapjack servers
* Modify config.rb to use Appraisal-specific configuration (instead of relying of Flapjack::VERSION)
* Support for multiple Flapjack instances to be run in parallel (support Flapjack 2.0's multi-instance execution model).
* More tests for "real world" scenarios (e.g. related services outages, different check types).
* Remove threading in outage tests.
* Outage equilibrium tests.
* Test notification mechanism under load.
* Reintroduce sync test - testing performance while JSON API is being used to update the contacts, etc database.
* General clean up of code.
* Self-test code, to verify config builder, etc.
* Remove integral gain from flood tests - doesn't really work.


