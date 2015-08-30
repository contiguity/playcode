require 'cinch'

require_relative 'game'
require_relative 'constants'

$pm_users = Set.new

module Cinch

  class Message
    old_reply = instance_method(:reply)

    define_method(:reply) do |*args|
      if self.channel.nil? && !$pm_users.include?(self.user.nick)
        self.user.send(args[0], true)
      else
        old_reply.bind(self).(*args)
      end
    end
  end

end

module Cinch

  class User
    old_send = instance_method(:send)

    define_method(:send) do |*args|
      old_send.bind(self).(args[0], !$pm_users.include?(self.nick))
    end
  end

  module Plugins

    class CodeGame
      include Cinch::Plugin

      def initialize(*args)
        super
        @active_game = Game.new
        @channel_name = config[:channel]
      end

      match /join/i, :method => :join
      match /leave/i, :method => :leave
      match /start/i, :method => :start

      match /redagent/i, :method => :toggle_red_agent
      match /blueagent/i, :method => :toggle_blue_agent
      match /forceword (.*)/i, :method => :toggle_force_word
      match /help/i, :method => :help
      match /rules/i, :method => :rules
      match /settings/i, :method => :settings

      match /who/i, :method => :who
      match /square/i, :method => :turn_on_square#not setup
      match /setupwords/i, :method =>:setup_words

      match /wordlist/, :method => :reply_with_word_list_for_user
      match /guess (.*)/, :method => :guess
      match /touch (.*)/, :method => :guess
      match /pass/, :method => :pass
      #match /clue (.*) (\d+)/i, :method => :clue
      match /forcereset/i, :method => :forcereset
      match /reset/i, :method => :forcereset #all players can reset if they're in the game
      #match /infodebug/i, :method => :info
      match /status/i, :method => :status



      def help(m)
        User(m.user).send '--------Basic commands--------'
        User(m.user).send '!help to see this help screen'
        User(m.user).send '!settings to see game settings'
        User(m.user).send '!join to join a game'
        User(m.user).send '!leave to leave a game'
        User(m.user).send '!start to start a game'
        User(m.user).send '----------------'
        User(m.user).send '!guess (word) to guess a word'
        User(m.user).send '!pass to pass (done manually)'
        User(m.user).send '!wordlist to see the remaining words (when in a game)'
        User(m.user).send '!status to see what words have been guessed'
        User(m.user).send '----------------'
      end

      def rules(m)
        User(m.user).send '--------Basic rules--------'
        User(m.user).send 'Based on codewords, players will get several words each game.'
        User(m.user).send 'and each player will be on the red team or the blue team'
        User(m.user).send 'Each team has an agent, who knows the type of each word'
        User(m.user).send 'The red agent wants their team to guess the red words'
        User(m.user).send 'and the blue agent wants their team to guess the blue words'
        User(m.user).send 'There are also neutral words, and one (or more) assassin words.'
        User(m.user).send '--------Revealing words--------'
        User(m.user).send 'A team wins by having all their color words guessed by their team.'
        User(m.user).send 'The agents alternate giving clues each round.'
        User(m.user).send 'An agent can give a clue consisting of a noun, then a number'
        User(m.user).send 'to clue multiple words to their team at a time.'
        User(m.user).send 'The agent\'s team can keep guessing until they hit a word that\'s not their color,'
        User(m.user).send 'they run out of guesses (1 more than the number said), or decide to stop'
        User(m.user).send 'However, they lose instantly if the assassin word is revealed.'
        User(m.user).send '----------------'
      end

      def join(m)
        if @active_game.started
          User(m.user).send 'Game already started'
        elsif @active_game.user_hash.include?(m.user.nick)
          Channel(@channel_name).send " #{m.user.nick} already joined. Game has #{@active_game.players_joined} player(s)."
        else
          @active_game.add_user(m.user)
          Channel(@channel_name).send " #{m.user.nick} joined. Game now has #{@active_game.players_joined} player(s)."
        end
      end

      def leave(m)
        if @active_game.started
          User(m.user).send 'Game already started'
        else
          @active_game.remove_user(m.user)
          Channel(@channel_name).send "#{m.user.nick} left. Game now has #{@active_game.players_joined} player(s)."
        end
      end

      def show_players_in_game() #m
        Channel(@channel_name).send "Players in game: #{@active_game.user_hash.keys.join(', ')}"
      end

      def toggle_red_agent(m)
        if @active_game.started
          Channel(@channel_name).send "Game has started. Use !reset to reset the game if you want to change agents."
          return
        end
        player_name=m.user.nick
        if @active_game.red_agent==player_name
          @active_game.red_agent=nil
          Channel(@channel_name).send "Player #{player_name} is no longer the red agent"
        else
          @active_game.red_agent=player_name
          Channel(@channel_name).send "Now #{player_name} is the red agent"
        end
      end

      def toggle_blue_agent(m)
        if @active_game.started
          Channel(@channel_name).send "Game has started. Use !reset to reset the game if you want to change agents."
          return
        end
        player_name=m.user.nick
        if @active_game.blue_agent==player_name
          @active_game.blue_agent=nil
          Channel(@channel_name).send "Player #{player_name} is no longer the blue agent"
        else
          @active_game.blue_agent=player_name
          Channel(@channel_name).send "Now #{player_name} is the blue agent"
        end
      end

      def toggle_force_word(m, input_word)
        if @active_game.force_words.include?(input_word)
          @active_game.force_words.delete(input_word)
          Channel(@channel_name).send "Removed #{input_word} from force words"
        else
          @active_game.force_words.push(input_word)
          Channel(@channel_name).send "Added #{input_word} to force words"
        end
      end

      def start(m)
        if @active_game.started
          User(m.user).send 'Game has started already'
        elsif @active_game.players_joined<4
          User(m.user).send 'Need at least 4 players'
        else

          @active_game.setup_game

          @active_game.user_hash.keys.each do |single_name|
            current_player=Player.new()
            current_player.set_name(single_name)
            current_player.set_user(@active_game.user_hash[single_name])
            @active_game.player_hash[single_name]=current_player
          end

          Channel(@channel_name).send "Game has started with #{@active_game.playing_user_names.join(', ')}."
          Channel(@channel_name).send "Red team: #{@active_game.red_team.join(', ')} (Agent: #{@active_game.red_agent})"
          Channel(@channel_name).send "Blue team: #{@active_game.blue_team.join(', ')} (Agent: #{@active_game.blue_agent})"
          Channel(@channel_name).send "The #{@active_game.current_team} team goes first."

          sleep(1)
          @active_game.user_hash.keys.each do |single_name|
            reply_with_word_list_for_name(single_name)
          end

        end
      end


      def guess(m, guessword)
        return unless @active_game.user_in_started_game(m.user)

        team=@active_game.current_team
        guesser=m.user.nick
        unless (team=='red'&&@active_game.red_team.include?(guesser))||(team=='blue'&&@active_game.blue_team.include?(guesser))
          Channel(@channel_name).send "Only the #{team} team can guess now"
          return
        end
        if (guesser==@active_game.red_agent)||(guesser==@active_game.blue_agent)
          Channel(@channel_name).send "Agents may not guess"
          return
        end
        unless @active_game.words.include?(guessword)
          Channel(@channel_name).send "Don't know which word is #{guessword}"
          return
        end

        sleep(1)

        round_continues=false
        if @active_game.red_words.include?(guessword)
          @active_game.revealed_words[guessword]='red'
          @active_game.red_words.delete(guessword)
          if team=='red'
            round_continues=true
          end
        elsif @active_game.blue_words.include?(guessword)
          @active_game.revealed_words[guessword]='blue'
          @active_game.blue_words.delete(guessword)
          if team=='blue'
            round_continues=true
          end
        elsif @active_game.assassin_words.include?(guessword)
          Channel(@channel_name).send "#{guessword} is an assassin word! The #{@active_game.current_team} tean loses!"
          reset_game()
          return
        elsif @active_game.neutral_words.include?(guessword)
          @active_game.revealed_words[guessword]='neutral'
          @active_game.neutral_words.delete(guessword)
        else
          Channel(@channel_name).send "Don't know what type is #{guessword}"
          return
        end
        Channel(@channel_name).send "#{guessword} is a #{@active_game.revealed_words[guessword].upcase} word"
        next_round() unless round_continues

        if @active_game.red_words.empty?
          Channel(@channel_name).send "Red team has guessed all their words and wins!"
          reset_game()
        elsif @active_game.blue_words.empty?
          Channel(@channel_name).send "Blue team has guessed all their words and wins!"
          reset_game()
        end
      end

      def pass(m)
        return unless @active_game.user_in_started_game(m.user)
        team=@active_game.current_team
        guesser=m.user.nick
        unless (team=='red'&&@active_game.red_team.include?(guesser))||(team=='blue'&&@active_game.blue_team.include?(guesser))
          Channel(@channel_name).send "Only the #{team} team can pass now"
          return
        end
        if (guesser==@active_game.red_agent)||(guesser==@active_game.blue_agent)
          Channel(@channel_name).send "Agents may not pass"
          return
        end
        Channel(@channel_name).send"The #{team} team passes."
        next_round()
      end

      def next_round
        team=@active_game.current_team
        if(team=='red')
          @active_game.current_team='blue'
        elsif(team=='blue')
          @active_game.current_team='red'
        end
        Channel(@channel_name).send"The #{@active_game.current_team} team may now give their next codeword."
      end

      def reply_with_word_list_for_user(m)
        reply_with_word_list_for_name(m.user.nick)
      end

      def reply_with_word_list_for_name(input_name)
       #current_player=@active_game.player_hash[input_name]
        current_user=@active_game.user_hash[input_name]

          current_user.send "==========="
        if input_name==@active_game.red_agent
          current_user.send("You are the RED agent")
          current_user.send("Red words: #{@active_game.red_words.join(', ')}")
          current_user.send("Blue words: #{@active_game.blue_words.join(', ')}")
          current_user.send("Neutral words: #{@active_game.neutral_words.join(', ')}")
          current_user.send("Assassin words: #{@active_game.assassin_words.join(', ')}")
        elsif input_name==@active_game.blue_agent
          current_user.send("You are the BLUE agent")
          current_user.send("Blue words: #{@active_game.blue_words.join(', ')}")
          current_user.send("Red words: #{@active_game.red_words.join(', ')}")
          current_user.send("Neutral words: #{@active_game.neutral_words.join(', ')}")
          current_user.send("Assassin words: #{@active_game.assassin_words.join(', ')}")
        else
          team='spectator'
          team='RED' if @active_game.red_team.include?(input_name)
          team='BLUE' if @active_game.blue_team.include?(input_name)
          current_user.send("You are on the #{team} team")
          current_user.send("All words: #{@active_game.words.join(', ')}")
        end
        current_user.send "==========="
      end

      def setup_words(m)
        return unless @active_game.user_in_started_game?(m.user)
        @active_game.setup_words
        Channel(@channel_name).send("Words were reset by #{m.user.nick}")

        sleep(1)
        @active_game.user_hash.keys.each do |single_name|
          reply_with_word_list_for_name(single_name)
        end

      end

      def who(m)
        Channel(@channel_name).send("Players in the game: #{@active_game.user_hash.keys.join(", ")}")
      end

      def forcereset(m)
        #only users in the game can reset it
        self.reset_game if @active_game.user_in_started_game?(m.user)
      end

      def reset_game
        Channel(@channel_name).send "The game has been reset."
        Channel(@channel_name).send("Red words: #{@active_game.red_words.join(', ')}")
        Channel(@channel_name).send("Blue words: #{@active_game.blue_words.join(', ')}")
        Channel(@channel_name).send("Neutral words: #{@active_game.neutral_words.join(', ')}")
        Channel(@channel_name).send("Assassin words: #{@active_game.assassin_words.join(', ')}")
        @active_game=Game.new
      end

      def settings(m)
        Channel(@channel_name).send "Game settings: #{WORDS_PER_GAME} used out of a list of #{WORDS.length}"
        Channel(@channel_name).send "First team has #{FIRST_WORDS}, Second team has #{SECOND_WORDS}, Assassin words; #{ASSASSIN_WORDS}"
      end

      def status(m)
        return unless @active_game.user_in_started_game(m.user)

        Channel(@channel_name).send "Current team #{@active_game.current_team}"
        Channel(@channel_name).send "Red agent: #{@active_game.red_agent}; Blue agent: #{@active_game.blue_agent}"
        remaining_words=@active_game.words.dup
        revealed_red_words=remaining_words.select{ |word| @active_game.revealed_words[word]=='red' }
        revealed_blue_words=remaining_words.select { |word| @active_game.revealed_words[word]=='blue' }
        revealed_neutral_words=remaining_words.select{ |word| @active_game.revealed_words[word]=='neutral' }
        remaining_words=remaining_words-revealed_red_words-revealed_blue_words-revealed_neutral_words

        Channel(@channel_name).send "Revealed red words: #{revealed_red_words.join(', ')} (#{@active_game.red_words.length} left)"
        Channel(@channel_name).send "Revealed blue words: #{revealed_blue_words.join(', ')} (#{@active_game.blue_words.length} left)"
        Channel(@channel_name).send "Revealed neutral words: #{revealed_neutral_words.join(', ')}  (#{@active_game.neutral_words.length} left)"
        Channel(@channel_name).send "Remaining words: #{remaining_words.join(', ')}"
      end

    end
  end
end