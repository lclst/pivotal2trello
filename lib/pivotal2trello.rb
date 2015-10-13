module Pivotal2Trello
  # Your code goes here...
  autoload :VERSION, 'pivotal2trello/version'

  module Commands
    autoload :BaseCommand, 'pivotal2trello/commands/base_command'
    autoload :DumpPivotal, 'pivotal2trello/commands/dump_pivotal'
    autoload :Migrate,     'pivotal2trello/commands/migrate'
    autoload :AddAdmin,    'pivotal2trello/commands/add_admin'
  end
end
