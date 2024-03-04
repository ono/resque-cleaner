## 0.5.0 (2024-03-04)

* Add link to Sentry issues in the event list view based on the current filters (other than regex)

## 0.4.1 (2018-01-25)

* Remove Requeue version lock (#46)

## 0.4.0 (2017-11-20)

* Render CSS as ERB partial to make Rails 5 compatible (#45)

## 0.3.2 (2016-03-09)

* Handle failure JSON with nil on payload safely (#40)

## 0.3.1 (2016-01-28)

* Bug fix: fix the issue regex is not applied on bulk clearance (#36)

## 0.3.0 (2014-05-27)

* Search by regex (#27)
* Show stats by exception (#29)
* Stop supporting ruby 1.8.x and 1.9.2
* Escape query parameters (#30)

## 0.2.12 (2013-12-03)

* Remove Resque::Helpers include (#23)
* Tweak Gemspec (#24)
* Don't use yaml format to show arguments
* Tweak README

## 0.2.11 (2013-07-19)

* Use transaction for retry-and-clear (#22).
* Fix for CI

## 0.2.10 (2012-10-15)

* Bug fix: use URL helper to support resque-web which is not hosted under '/'.

## 0.2.9 (2012-05-10)

* Make limiter configurable on resque-web.

## 0.2.8 (2012-03-19)

* UI tweak (#15)

## 0.2.7 (2012-01-17)

* Support Travis CI
* Support failure jobs without payload information (#11).

## 0.2.6 (2011-08-23)

* Follow the latest resque for date format.

## 0.2.5 (2011-05-05)

* BUGFIX: Pagination has been broken.
* Dump a list as JSON format.

## 0.2.4 (2011-04-19)

* BUGFIX: "Select All" ignores exception filter.

## 0.2.3 (2011-04-11)

* Exception filter.

## 0.2.2 (2011-04-07)

* Changed a way to load yajl/json\_gem.

## 0.2.1 (2011-04-06)

* BUGFIX: Bulk action didn't work properly when you select all jobs.
* Removed absolute paths from html.

## 0.2.0 (2011-04-06)

* Extended with resque-web

## 0.1.1 (2010-12-30)

* Fixed for ruby 1.9.2
* Fixed a bug on #retried? method

## 0.1.0 (2010-11-24)

* First official release


