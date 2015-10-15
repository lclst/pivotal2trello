module Pivotal2Trello
  module Commands
    class AddAdmin < BaseCommand
      def initialize(args, options)
        super

        # Create or find organizations boards on Trello
        trello_user = trello.find(:member, 'me')
        if options.organization
          trello_organization = trello.find(:organization, options.organization)
        else
          say "Specify trello organization with --organization"

          say "%24s %s" % ['ID', 'Name']

          trello_user.organizations.each do |org|
            say "%24s %s" % [org.id, org.display_name]
          end

          return
        end

        if options.user
          new_trello_admin = trello.find(:member, options.user)
        else
          say "Specify new admin user with --user"

          say "%24s %s" % ['ID', 'Name']

          trello_organization.members.each do |member|
            say "%24s %s (@%s)" % [member.id, member.full_name, member.username]
          end

          return
        end

        say "Adding #{new_trello_admin.full_name} (@#{new_trello_admin.username}) to all boards"

        @trello_boards = trello_organization.boards
        @trello_boards.each do |board|
          say " - #{board.name}"
          board.add_member new_trello_admin, :admin
          sleep 0.5
        end
      end # def initialize
    end # class DumpPivotal
  end # module Commands
end # module Pivotal2Trello
