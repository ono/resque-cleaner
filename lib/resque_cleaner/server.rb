# Extends Resque Web Based UI.
# Structure has been borrowed from ResqueScheduler.
module ResqueCleaner
  module Server
    def self.erb_path(filename)
      File.join(File.dirname(__FILE__), 'server', 'views', filename)
    end
    def self.public_path(filename)
      File.join(File.dirname(__FILE__), 'server', 'public', filename)
    end

    def self.included(base)

      base.class_eval do
        helpers do

        end

        get "/cleaner" do
          @stats = cleaner.stats_by_class

          erb File.read(ResqueCleaner::Server.erb_path('cleaner.erb'))
        end

        get /cleaner\/public\/([a-z]+\.[a-z]+)/ do
          send_file ResqueCleaner::Server.public_path(params[:captures].first)
        end
      end

    end

    def cleaner
      @cleaner ||= Resque::Plugins::ResqueCleaner.new
      @cleaner.print_message = false
      @cleaner
    end
    Resque::Server.tabs << 'Cleaner'
  end
end

Resque::Server.class_eval do
  include ResqueCleaner::Server
end

