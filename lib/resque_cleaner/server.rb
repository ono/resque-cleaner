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
          def time_filter(id, name, value)
            html = "<select id=\"#{id}\" name=\"#{name}\">"
            html += "<option value=\"\">-</option>"
            [1, 3, 6, 12, 24].each do |h|
              selected = h.to_s == value ? 'selected="selected"' : ''
              html += "<option #{selected} value=\"#{h}\">#{h} #{h==1 ? "hour" : "hours"} ago</option>"
            end
            [3, 7, 14, 28].each do |d|
              selected = (d*24).to_s == value ? 'selected="selected"' : ''
              html += "<option #{selected} value=\"#{d*24}\">#{d} days ago</option>"
            end
            html += "</select>"
          end
        end

        get "/cleaner" do
          load_cleaner_filter
          block = lambda{|j|
            (!@from || j.after?(hours_ago(@from))) &&
            (!@to || j.before?(hours_ago(@to)))
          }

          @stats = cleaner.stats_by_class &block
          @count = cleaner.select(&block).size

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

    def load_cleaner_filter
      @from = params[:f]=="" ? nil : params[:f]
      @to = params[:t]=="" ? nil : params[:t]
    end

    def hours_ago(h)
      Time.now - h.to_i*60*60
    end
    Resque::Server.tabs << 'Cleaner'
  end
end

Resque::Server.class_eval do
  include ResqueCleaner::Server
end

