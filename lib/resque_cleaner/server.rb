# Extends Resque Web Based UI.
# Structure has been borrowed from ResqueScheduler.
module ResqueCleaner
  module Server
    def self.erb_path(filename)
      File.join(File.dirname(__FILE__), 'server', 'views', filename)
    end

    def self.included(base)

      base.class_eval do
        helpers do
        end

        get "/cleaner" do
          erb File.read(ResqueCleaner::Server.erb_path('cleaner.erb'))
        end
      end

    end
    Resque::Server.tabs << 'Cleaner'
  end
end

Resque::Server.class_eval do
  include ResqueCleaner::Server
end

