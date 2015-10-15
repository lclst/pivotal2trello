module Pivotal2Trello
  module Commands
    class Migrate < BaseCommand
      def initialize(args, options)
        super

        @list_cards = {}
        @list_for_epic_states = {}

        # Default trello board for unmapped items
        default_board = 'Little Things'

        unless options.project
          say "Specify a Pivotal project with --project ID"

          say "%8s %s" % ['ID', 'Name']

          pivotal.projects.each do |pr|
            say "%8s %s" % [pr.id, pr.name]
          end

          return
        end

        @project = pivotal.project(options.project)

        say "Migrating project #{@project.name} (#{@project.id})"

        # Load labels and epics, to map to a board
        @pivotal_labels = {}
        @project.labels.each do |label|
          @pivotal_labels[label.id] = label.name
        end

        @pivotal_epics = {}
        @project.epics.each do |epic|
          @pivotal_epics[epic.id] = {name: epic.name, label: epic.label.id}
        end

        if options.epic_id
          @pivotal_epics = {
            options.epic_id.to_i => @pivotal_epics[options.epic_id.to_i]
          }
        end

        debug "Labels"
        debug @pivotal_labels.inspect
        debug

        debug "Epics"
        debug @pivotal_epics.inspect
        debug

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

        @trello_boards = trello_organization.boards

        # Find or create a trash board
        trash_board = @trello_boards.find{|b| b.name == 'Trash'}
        unless trash_board
          say "Creating private Trash board..."
          trash_board = trello.create(:board,
            'name' => 'Trash',
            'idOrganization' => trello_organization.id
          )
        end

        # Map pivotal epics to trello boards
        @epics_to_boards = {}
        @pivotal_epics.each do |id, epic|
          new_board = false
          # Look for a board
          board = @trello_boards.find do |b|
            b.name == epic[:name]
          end

          # ...or create it
          unless board
            board_attributes = {
              'idOrganization' => trello_organization.id,
              'name' => epic[:name],
              'prefs_permissionLevel' => 'org'
            }

            say "Creating board for #{epic[:name]} with attrs #{board_attributes}..."

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

          @epics_to_boards[id] = board
        end

        # Load tasks into boards
        tasks_by_board = {}

        if options.epic_id
          # Only stories in the specified epic
          stories = @project.stories(with_label: @pivotal_labels[@pivotal_epics[options.epic_id][:label]])
        else
          # All stories
          stories = @project.stories
        end
        num_stories = stories.count
        i = 0

        say "Scanning #{num_stories} stories..."
        start_at = options.start_at.to_i
        say "  Starting at #{start_at}" if start_at > 0

        stories.each do |story|
          # Progress
          i += 1

          next if i < start_at

          if i % 5 == 0
            say "Story %d / %d %0.2f%%" % [i, num_stories, (i/num_stories.to_f)*100.0]
            sleep 10
          end

          # Determine the board and list for this story
          target_board, target_list = find_board_and_list story
          debug "story: #{story.id} #{story.name}"
          debug "  -> to board: #{target_board.id} #{target_board.name}"
          debug "         list: #{target_list.try(:id)} #{target_list.try(:name)}"

          unless options.log_only
            card = update_or_create_card story, target_board, target_list
            debug " card: #{card.id} #{card.attributes.inspect}"
          end

          sleep 2
        end
      end # def initialize

      # Find the trello board and list for the specified story
      def find_board_and_list(story)
        # Find epic labels from story
        epics = story.labels.map do |label|
          @pivotal_epics.find {|k,v| v[:label] == label.id}
        end.compact.uniq

        # Drop little things if others are present
        if epics.length > 1
          epics = epics.reject do |epic|
            epic.last[:name] == 'Little Things'
          end
        end

        # or add little things if it needs one
        if epics.length == 0
          epics = @pivotal_epics.select do |k, v|
            v[:name] == 'Little Things'
          end
        end

        epics = epics.first

        # Find board for this epic
        target_board = @epics_to_boards[epics.first]

        # And the list, based on the story state
        target_list = @list_for_epic_states[[epics.first, story.current_state]] ||= begin
          target_list_name = @list_for_epic_states[[epics.first, story.current_state]] || case story.current_state
          when 'accepted', 'delivered', 'finished' # done
            'Done'
          when 'started' # doing
            'Doing'
          when 'unstarted', 'planned' # backlog
            'Backlog'
          else # 'unscheduled' # icebox
            'Icebox'
          end

          target_board.lists.find do |list|
            list.name == target_list_name
          end
        end

        [target_board, target_list]
      end

      # Find and update, or create the card for the story in target_board and target_list
      #
      # Matches cards based on name
      def update_or_create_card(story, target_board, target_list)
        @list_cards[target_list] ||= target_list.cards

        # Find a matching card
        card = @list_cards[target_list].find do |c|
          c.name == story.name
        end

        unless card
          card = Trello::Card.new
          card.client = trello
          card.pos = 'bottom'
        end

        card.name = story.name
        card.desc = story.description
        card.list_id = target_list.id
        card.save

        sleep 0.5

        # Apply labels.
        # These use the POST /1/cards/[id]/labels endpoint to assign labels by name and color

        # Array of [name, color] for desired labels
        labels = []

        # Story type label
        case story.story_type
        when 'feature'
          type_label = 'Feature'
          type_color = 'blue'
        when 'bug'
          type_label = 'Bug'
          type_color = 'red'
        when 'chore'
          type_label = 'Chore'
          type_color = 'yellow'
        when 'release'
          type_label = 'Release'
          type_color = 'green'
        end

        labels << [type_label, type_color]

        # And other labels except the epic name
        story.labels.each do |label|
          next if @pivotal_epics.any?{|id, epic| epic[:label] == label.id}
          labels << [label.name, nil]
        end

        # And a label for points assigned to the story
        labels << ["P#{story.estimate.to_i}", nil] if story.estimate

        current_labels = card.labels.map(&:name)
        labels.each do |label|
          name, color = label
          unless current_labels.include?(name)
            trello.post("/cards/#{card.id}/labels", name: name, color: color)
            sleep 0.5
          end
        end

        # Story comments
        story_comments = story.comments
        story_comments.each do |comment|
          author = find_person(comment.person_id)
          author_name = author ? author.name : 'Someone'

          comment_text = "#{author_name} - #{comment.created_at.strftime("%b %-d, %Y %-l:%M%P")}\n\n"
          comment_text << comment.text.to_s

          # Post the comment unless one exists
          matching_comment = card.actions.find do |trello_comment|
            trello_comment.type == 'commentCard' && trello_comment.data['text'].strip == comment_text.strip
          end

          card.add_comment(comment_text) unless matching_comment
          sleep 0.5
        end

        card
      end # def update_or_create_card

      # Find a member of the project for +person_id+
      def find_person(person_id)
        @project_people ||= @project.memberships

        person = @project_people.find do |membership|
          membership.person.id == person_id
        end

        person.nil? ? nil : person.person
      end
    end # class DumpPivotal
  end # module Commands
end # module Pivotal2Trello
