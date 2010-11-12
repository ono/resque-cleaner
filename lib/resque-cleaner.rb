module Resque
  module Plugins
    # ResqueCleaner class provides useful functionalities to retry or clean
    # failed jobs.
    class ResqueCleaner
      # ResqueCleaner fetches all elements from Redis once and checks them
      # by linear when filtering. Since there is a performance concern,
      # ResqueCleaner only targets the latest x(default 1000) jobs.
      # You can change the value. e.g. cleaner.limiter.maximum = 2000
      attr_reader :limiter

      # Set false if you don't show any message.
      attr_accessor :print_message

      # Initializes instance
      def initialize
        @failure = Resque::Failure.backend
        @print_message = true
        @limiter = Limiter.new
      end

      # Returns redis instance.
      def redis
        Resque.redis
      end

      # Returns failure backend. Only supports redis backend.
      def failure
        @failure
      end

      # Outputs summary of failure jobs by date.
      def summary_by_date
        jobs = @limiter.jobs
        summary = {}
        jobs.each do |job|
          date = job["failed_at"][0,10]
          summary[date] ||= 0
          summary[date] += 1
        end if jobs

        if print?
          log too_many_message if @limiter.on?
          summary.keys.sort.each do |k|
            log "%s: %4d" % [k,summary[k]]
          end
          log "%10s: %4d" % ["total", @limiter.count]
        end
        summary
      end

      def summary_by_class
      end

      # Returns every jobs for which block evaluates to true.
      def select(&block)
        jobs = @limiter.jobs
        @limiter.jobs.select &block if jobs
      end

      # Clears every jobs for which block evaluates to true.
      def clear(&block)

      end

      # Retries every jobs for which block evaluates to true.
      def retry(&block)
      end

      # Retries and clears every jobs for which block evaluates to true.
      def retry_and_clear(&block)
      end

      # Clears all jobs except the last x jobs
      def clear_stale
        return unless @limiter.on?
        redis.ltrim(:failed, -@limiter.maximum, -1)
      end

      # Returns 
      def proc(&block)
        FilterProc.new(&block)
      end

      # Provides typical proc you can filter jobs.
      class FilterProc < Proc
        def retried
          FilterProc.new {|job| self.call(job) && job['retried_at'].blank?}
        end

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
        end

        # Returns true if limiter is ON: number of failed jobs is more than
        # maximum value.
        def on?
          @cleaner.failure.count > @maximum
        end

        def count
          on? ? @maximum : @cleaner.failure.count
        end

        def jobs
          jobs = @cleaner.failure.all( - count, count)
          jobs.is_a?(Array) ? jobs : [jobs] if jobs
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
        "There are too many failed jobs(count=#{@failure.count}). This only looks into last #{@limiter.maximum} jobs."
      end
    end
  end
end

require 'pp'

h = ResqueFailureHelper.new



