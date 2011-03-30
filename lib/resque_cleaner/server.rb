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

          def class_filter(id, name, klasses, value)
            html = "<select id=\"#{id}\" name=\"#{name}\">"
            html += "<option value=\"\">-</option>"
            klasses.each do |k|
              selected = k == value ? 'selected="selected"' : ''
              html += "<option #{selected} value=\"#{k}\">#{k}</option>"
            end
            html += "</select>"
          end
        end

        get "/cleaner" do
          load_cleaner_filter

          @jobs = cleaner.select
          @stats, @total = {}, {"total" => 0, "1h" => 0, "3h" => 0, "1d" => 0, "3d" => 0, "7d" => 0}
          @jobs.each do |job|
            klass = job["payload"]["class"]
            failed_at = Time.parse job["failed_at"]

            @stats[klass] ||= {"total" => 0, "1h" => 0, "3h" => 0, "1d" => 0, "3d" => 0, "7d" => 0}
            items = [@stats[klass],@total]

            items.each{|a| a["total"] += 1}
            items.each{|a| a["1h"] += 1} if failed_at >= hours_ago(1)
            items.each{|a| a["3h"] += 1} if failed_at >= hours_ago(3)
            items.each{|a| a["1d"] += 1} if failed_at >= hours_ago(24)
            items.each{|a| a["3d"] += 1} if failed_at >= hours_ago(24*3)
            items.each{|a| a["7d"] += 1} if failed_at >= hours_ago(24*7)
          end

          erb File.read(ResqueCleaner::Server.erb_path('cleaner.erb'))
        end

        get "/cleaner_list" do
          load_cleaner_filter

          block = lambda{|j|
            (!@from || j.after?(hours_ago(@from))) &&
            (!@to || j.before?(hours_ago(@to))) &&
            (!@klass || j.klass?(@klass))
          }

          @failed = cleaner.select(&block).reverse

          @klasses = cleaner.stats_by_class.keys
          @count = cleaner.select(&block).size

          erb File.read(ResqueCleaner::Server.erb_path('cleaner_list.erb'))
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
      @klass = params[:c]=="" ? nil : params[:c]
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

