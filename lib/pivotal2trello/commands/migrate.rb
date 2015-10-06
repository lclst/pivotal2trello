module Pivotal2Trello
  module Commands
    class Migrate < BaseCommand
      def initialize(args, options)
        super

        # Default trello board for unmapped items
        default_board = 'Little Things'

        unless options.project
          say "Specify a Pivotal project with --project ID"

          puts "%8s %s" % ['ID', 'Name']

          pivotal.projects.each do |pr|
            puts "%8s %s" % [pr.id, pr.name]
          end

          return
        end

        project = pivotal.project(options.project)

        say "Migrating project #{project.name} (#{project.id})"

        # Load labels and epics, to map to a board
        pivotal_labels = {}
        project.labels.each do |label|
          pivotal_labels[label.id] = label.name
        end

        pivotal_epics = {}
        project.epics.each do |epic|
          pivotal_epics[epic.id] = {name: epic.name, label: epic.label.id}
        end

        puts "Labels"
        puts pivotal_labels.inspect
        puts

        puts "Epics"
        puts pivotal_epics.inspect
        puts

        # Create or find organizations boards on Trello
        trello_user = trello.find(:member, 'me')
        if options.organization
          trello_organization = trello.find(:organization, options.organization)
        else
          say "Specify trello organization with --organization"

          puts "%24s %s" % ['ID', 'Name']

          trello_user.organizations.each do |org|
            puts "%24s %s" % [org.id, org.display_name]
          end

          return
        end

        trello_boards = trello_organization.boards

        # Find or create a trash board
        trash_board = trello_boards.find{|b| b.name == 'Trash'}
        unless trash_board
          say "Creating private Trash board..."
          trash_board = trello.create(:board,
            'name' => 'Trash',
            'idOrganization' => trello_organization.id
          )
        end

        # Map pivotal epics to trello boards
        epics_to_boards = {}
        pivotal_epics.each do |id, epic|
          new_board = false
          # Look for a board
          board = trello_boards.find do |b|
            b.name == epic[:name]
          end

          # ...or create it
          unless board
            board_attributes = {
              'idOrganization' => trello_organization.id,
              'name' => epic[:name],
              'prefs_permissionLevel' => 'org'
            }

            puts "Creating board for #{epic[:name]} with attrs #{board_attributes}..."

            board = trello.create(:board, board_attributes)
          end

          if new_board || options.fix_boards
            say "Fixing board #{board.id} #{board.name}..."

            # Set permissions
            if board.prefs['permissionLevel'] != 'org'
              say "  Setting permissionLevel to org..."
              board.prefs['permissionLevel'] = 'org'
              board.save
            end

            board_lists = board.lists

            # Create our lists
            wanted_lists = ['Doing', 'Backlog', 'Icebox', 'Done']
            wanted_lists.each do |list_name|
              next if board_lists.find {|list| list.name == list_name}
              say "  Creating list #{list_name}..."
              trello.create(:list, 'idBoard' => board.id, 'name' => list_name)
            end

            # ...and remove extra lists
            board_lists.each do |list|
              unless wanted_lists.include?(list.name)
                say "  Removing list #{list.name}..."
                trello.put("/lists/#{list.id}/idBoard", value: trash_board.id)
              end
            end

            # ...and reorder main lists
            board_lists = board.lists
            have_lists = board_lists.map{|list| list.name}

            unless have_lists == wanted_lists
              say "  Reordering lists..."
              wanted_lists.reverse.each do |list_name|
                list = board_lists.find {|list| list.name == list_name}
                next unless list
                trello.put("/lists/#{list.id}/pos", value: 'top')
              end
            end
          end

          epics_to_boards[id] = board
        end




        return


        # Load tasks into new boards
        tasks_by_board = {}
        stories = project.stories
        num_stories = stories.count
        i = 0

        puts "Scanning #{num_stories} stories..."

        stories.each do |story|
          i += 1

          puts story.attributes
          return if i > 100

          if i % 100 == 0
            say "Story %d / %d %0.2f%%" % [i, num_stories, (i/num_stories.to_f)*100.0]
          end
        end

      end # def initialize
    end # class DumpPivotal
  end # module Commands
end # module Pivotal2Trello
