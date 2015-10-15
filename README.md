# Pivotal2trello

Migrate Pivotal Tracker stories and epics to Trello cards and boards

## Installation

Execute:

    $ bundle install

## Usage

This requires the Pivotal Tracker and Trello API keys to be set in environment variables:

Variable                | Description
----------------------- | -----------
PIVOTAL_TRACKER_API_KEY | Pivotal Tracker API key from your [profile](https://www.pivotaltracker.com/profile)
TRELLO_APP_KEY          | Trello Application key from [here](https://trello.com/app-key)
TRELLO_APP_SECRET       | Trello Application secret
TRELLO_TOKEN            | Trello Access Token (see below)

Once you have the application key and secret, you can request the access token from:

    https://trello.com/1/connect?name=pivotal2trello&response_type=token&scope=read,write&key=TRELLO_APP_KEY

After these are set, you can run:

    $ bundle exec bin/pivotal2trello --help

The `migrate` command is the primary command to migrate Pivotal Tracker stories to Trello cards. Each epic in Pivotal Tracker is converted to a separate board in the specified Trello organization.

This code makes some assumptions about the way tags and epics are used in Pivotal, and the naming of "Little Things" as a default board for stories not in an epic.

Attachments are not converted, nor are any timestamps or item ownership.

## Contributing

1. Fork it ( https://github.com/lclst/pivotal2trello/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
