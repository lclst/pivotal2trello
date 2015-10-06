module Pivotal2Trello
  module Commands
    class DumpPivotal < BaseCommand
      def initialize(args, options)
        super

        say "Pivotal user"
        say pivotal.me.attributes

        say 'Trello user'
        say trello.find(:member, 'me').attributes
      end
    end # class DumpPivotal
  end # module Commands
end # module Pivotal2Trello
