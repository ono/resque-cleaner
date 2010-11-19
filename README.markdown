Resque-Cleaner
==============

[github.com/ono/resque-cleaner](https://github.com/ono/resque-cleaner)


Description
-----------

(README: Work in progress)

ResqueCleaner is a [Resque](https://github.com/defunkt/resque) plugin which
helps you to deal with failure jobs of Resque. It gives you functionalities of:

* Showing stats of failure jobs
* Retrying failure jobs
* Removing failure jobs
* Filtering failure jobs

Although ResqueCleaner hasn't integrated with Resque web-interface, you can use
the functionality pretty easily on irb(console).


Installation
------------

Install as a gem:
    $ gem install resque-cleaner


Usage
-----

**Create Instance**

    > cleaner = Resque::Plugins::ResqueCleaner.new

**Show Stats**

Shows stats of failure jobs grouped by date.

    > cleaner.stats_by_date
    2009/03/13:    6
    2009/11/13:   14
    2010/08/13:   22
         total:   42
    => {'2009/03/10' => 6, ...}

You could group them by class.

    > cleaner.stats_by_class
         BadJob:    3
    HorribleJob:    7
          total:   10
    => {'BadJob' => 3, ...}

You can get the ones filtered with a block: it targets only jobs which the block
evaluetes true. e.g. Show stats only of jobs entried with argument(s).

    > cleaner.stats_by_date{|job| job["payload"]["args"].size > 0}
    2009/03/13:    3
    2009/11/13:    7
    2010/08/13:   11
         total:   22
    => {'2009/03/10' => 3, ...}

**Retry(Requeue)**

You can retry all failure jobs with this method.

    > cleaner.requeue

Of course, you can filter jobs with a block and it reques only jobs which the
block evaluates true. e.g. Retry only jobs entried with one or more arguments.

    > cleaner.requeue{|job| job["payload"]["args"].size > 0}

You can also use proc method whic defined some useful filter. e.g. Retry only jobs entried within a day.

    > cleaner.requeue &cleaner.proc.after(1.day.ago)

You can chain filters. e.g. Retry EmailJob entried with arguments within 3 days 

    > cleaner.requeue &cleaner.proc{|j| j["payload"]["args"]>2}.after(3.days.ago).klass(EmailJob)

NOTE:
[1.day.ago](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/numeric/time.rb)
is not in standard library.

**Clear**

You can clear all failure jobs with this method.

    > cleaner.clear

Like you can do with the retry method, the clear metod takes a block. Here are
some examples:

    > cleaner.clear &cleaner.proc.retried
      => clears all jobs already retried and returns number of the jobs.
    > cleaner.clear &cleaner.proc.queue(:low).before(10.days.ago)
      => clears all jobs entried in :low queue before 10 days ago.
    > cleaner.clear &cleaner.proc{|j| j["exception"]=="RuntimeError"}.queue(:low)
      => clears all jobs raised RuntimeError and queued :low queue

**Retry and Clear**

You can retry(requeue) and clear failure jobs at the same time; just pass true
as an argument. e.g. Retry EmailJob and remove from failure jobs.

    > cleaner.requeue(true) &cleaner.proc.klass(EmailJob)

**Select**

If you want to get jobs with filtering, the select method can do that. Here are
some examples:

    > cleaner.select {|j| j["exception"]=="RuntimeError"}
    > cleaner.select &cleaner.proc.after(2.days.ago)


Failure Job
-----------



Limiter
-------


... still in writing.


ToDo
----

* Integration with Resque's sinatra based front end.
* More stats.

Any suggestion are welcomed. Please send your suggestion through github issues.



