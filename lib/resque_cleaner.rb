require 'time'
module Resque
  module Plugins
    # ResqueCleaner class provides useful functionalities to retry or clean
    # failed jobs. Let's clean up your failed list!
    class ResqueCleaner
      include Resque::Helpers
      # ResqueCleaner fetches all elements from Redis and checks them
      # by linear when filtering them. Since there is a performance concern,
      # ResqueCleaner handles only the latest x(default 1000) jobs.
      #
      # You can change the value through limiter attribute.
      # e.g. cleaner.limiter.maximum = 5000
      attr_reader :limiter

      # Set false if you don't show any message.
      attr_accessor :print_message

      # Initializes instance
      def initialize
        @failure = Resque::Failure.backend
        @print_message = true
        @limiter = Limiter.new self
      end

      # Returns redis instance.
      def redis
        Resque.redis
      end

      # Returns failure backend. Only supports redis backend.
      def failure
        @failure
      end

      # Stats by date.
      def stats_by_date(&block)
        jobs = select(&block)
        summary = {}
        jobs.each do |job|
          date = job["failed_at"][0,10]
          summary[date] ||= 0
          summary[date] += 1
        end

        if print?
          log too_many_message if @limiter.on?
          summary.keys.sort.each do |k|
            log "%s: %4d" % [k,summary[k]]
          end
          log "%10s: %4d" % ["total", @limiter.count]
        end
        summary
      end

      # Stats by class.
      def stats_by_class
      end

      # Returns every jobs for which block evaluates to true.
      def select(&block)
        jobs = @limiter.jobs
        block_given? ? @limiter.jobs.select(&block) : jobs
      end

      # Clears every jobs for which block evaluates to true.
      def clear(&block)
        @limiter.lock do
          cleared = 0
          @limiter.jobs.each_with_index do |job,i|
            if !block_given? || block.call(job)
              index = @limiter.start_index + i - cleared
              # fetches again since you can't ensure that it is always true:
              # a == endode(decode(a))
              value = redis.lindex(:failed, index)
              redis.lrem(:failed, 1, value)
              cleared += 1
            end
          end
        end
      end

      # Retries every jobs for which block evaluates to true.
      def requeue(&block)
        @limiter.lock do
          @limiter.jobs.each_with_index do |job,i|
            if !block_given? || block.call(job)
              job['retried_at'] = Time.now.strftime("%Y/%m/%d %H:%M:%S")
              redis.lset(:failed, @limiter.start_index+i, Resque.encode(job))
              Job.create(job['queue'], job['payload']['class'], *job['payload']['args'])
            end
          end
        end
      end

      # Retries and clears every jobs for which block evaluates to true.
      def requeue_and_clear(requeue=true,clear=true,&block)
        cleared = 0
        @limiter.lock do
          @limiter.jobs.each_with_index do |job,i|
            if !block_given? || block.call(job)
              index = @limiter.start_index + i - cleared

              # removes job from :failed
              value = redis.lindex(:failed, index)
              redis.lrem(:failed, 1, value)
              cleared += 1

              # then requeues the job
              Job.create(job['queue'], job['payload']['class'], *job['payload']['args'])
            end
          end
        end
      end

      # Clears all jobs except the last X jobs
      def clear_stale
        return unless @limiter.on?
        redis.ltrim(:failed, -@limiter.maximum, -1)
      end

      # Returns Proc which you can add a useful condition easily.
      # e.g.
      # cleaner.clear &cleaner.proc.retried
      #   #=> Clears all jobs retried.
      # cleaner.select &cleaner.proc.after(10.days.ago).klass(EmailJob)
      #   #=> Selects all EmailJob failed within 10 days.
      # cleaner.select &cleaner.proc{|j| j["exception"]=="RunTimeError"}.klass(EmailJob)
      #   #=> Selects all EmailJob failed with RunTimeError.
      def proc(&block)
        FilterProc.new(&block)
      end

      # Provides typical proc you can filter jobs.
      class FilterProc < Proc
        def retried
          FilterProc.new {|job| self.call(job) && job['retried_at'].blank?}
        end
        alias :requeued :retried

        def before(time)
          time = Time.parse(time) if time.is_a?(String)
          FilterProc.new {|job| self.call(job) && Time.parse(job['failed_at']) <= time}
        end

        def after(time)
          time = Time.parse(time) if time.is_a?(String)
          FilterProc.new {|job| self.call(job) && Time.parse(job['failed_at']) >= time}
        end

        def klass(klass_or_name)
          FilterProc.new {|job| self.call(job) && job["payload"]["class"] == klass_or_name.to_s}
        end

        def queue(queue)
          FilterProc.new {|job| self.call(job) && job["queue"] == queue.to_s}
        end

        def self.new(&block)
          if block
            super
          else
            super {|job| true}
          end
        end
      end

      # Through the Limiter class, you accesses only the last x(default 1000)
      # jobs. 
      class Limiter
        DEFAULT_MAX_JOBS = 1000
        attr_accessor :maximum
        def initialize(cleaner)
          @cleaner = cleaner
          @maximum = DEFAULT_MAX_JOBS
          @locked = false
        end

        # Returns true if limiter is ON: number of failed jobs is more than
        # maximum value.
        def on?
          @cleaner.failure.count > @maximum
        end

        # Returns limited count.
        def count
          if @locked
            @jobs.size
          else
            on? ? @maximum : @cleaner.failure.count
          end
        end

        # Returns jobs. If numbers of jobs is more than maixum, it returns only
        # the maximum.
        def jobs
          if @locked
            @jobs
          else
            all( - count, count)
          end
        end

        # wraps Resque's all and returns always array.
        def all(index=0,count=1)
          jobs = @cleaner.failure.all( index, count)
          jobs = [] unless jobs
          jobs = [jobs] unless jobs.is_a?(Array)
          jobs
        end

        # Returns a start index of jobs in :failed list.
        def start_index
          if @locked
            @start_index
          else
            on? ? @cleaner.failure.count-@maximum : 0
          end
        end

        # Assuming new failures pushed while cleaner is dealing with failures,
        # you need to lock the range.
        def lock
          old = @locked

          unless @locked
            total_count = @cleaner.failure.count
            if total_count>@maximum
              @start_index = total_count-@maximum
              @jobs = all( @start_index, @maximum)
            else
              @start_index = 0
              @jobs = all( 0, total_count)
            end
          end

          @locked = true
          yield
        ensure
          @locked = old
        end
      end

      # Outputs message. Overrides this method when you want to change a output
      # stream.
      def log(msg)
        puts msg if print?
      end

      def print?
        @print_message
      end

      def too_many_message
        "There are too many failed jobs(count=#{@failure.count}). This only looks at last #{@limiter.maximum} jobs."
      end
    end
  end
end



