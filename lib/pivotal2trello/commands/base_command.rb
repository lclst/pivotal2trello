require 'yaml/store'
require 'trello'
require 'tracker_api'

module Pivotal2Trello
  module Commands
    class BaseCommand
      def initialize(args, options)
        options.default :config_file => File.join(ENV['HOME'], '.pivotal2trello')

        @options = options
        @args = args
        @debug = options.debug

        load_config
      end

      # Load the configuration from the configuration file, or the
      # environment
      def load_config
        if File.exist?(@options.config_file)
          store = YAML::Store.new(@options.config_file)
          store.transaction do
            @trello_token            = store['trello_token']
            @trello_app_key          = store['trello_app_key']
            @trello_app_secret       = store['trello_app_secret']
            @pivotal_tracker_api_key = store['privotal_tracker_api_key']
          end
        end

        # Pull in defaults from the environment
        @trello_token            = ENV['TRELLO_TOKEN']            if @trello_token.blank?
        @trello_app_key          = ENV['TRELLO_APP_KEY']          if @trello_api_key.blank?
        @trello_app_secret       = ENV['TRELLO_APP_SECRET']       if @trello_app_secret.blank?
        @pivotal_tracker_api_key = ENV['PIVOTAL_TRACKER_API_KEY'] if @pivotal_tracker_api_key.blank?
      end

      # Initialize or return the pivotal client
      def pivotal
        @pivotal ||= TrackerApi::Client.new(token: @pivotal_tracker_api_key)
      end

      # Initialize or return the trello client
      def trello
        @trello ||= Trello::Client.new(
          consumer_key: @trello_app_key,
          consumer_secret: @trello_app_secret,
          oauth_token: @trello_token,
          oauth_token_secret: @trello_token_secret
        )
      end

      # Log a debug message
      def debug(*parts)
        say "[DEBUG] " + parts.join(" ") if @debug
      end
    end # class DumpPivotal
  end # module Commands
end # module Pivotal2Trello
