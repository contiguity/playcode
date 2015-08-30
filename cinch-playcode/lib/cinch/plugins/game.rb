class Game
  attr_accessor :user_hash, :player_hash, :playing_user_names, :started, :words, :red_words, :blue_words, :neutral_words, :assassin_words, :revealed_words, :current_team, :red_team, :blue_team, :red_agent, :blue_agent, :wants_square_list, :shuffle_names, :force_words #could have more than one assassin word?

  def initialize
    self.player_hash = {}
    self.user_hash = {}
    self.playing_user_names=[]
    self.started = false
    self.shuffle_names = true
    self.revealed_words= {}
    self.force_words=[]
    self.red_agent=nil
    self.blue_agent=nil
  end

  def add_user(user)
    user_hash[user.nick]=user unless user_hash.has_key?(user.nick)
  end

  def remove_user(user)
    user_hash.delete(user.nick)
  end

  def setup_game
    self.started=true
    #self.phase=:main
    self.playing_user_names=self.user_hash.keys
    self.playing_user_names.shuffle! if self.shuffle_names
    self.words=WORDS.sample(WORDS_PER_GAME-force_words.length) if force_words.length<WORDS_PER_GAME
    puts "=================="
    puts "Words used this game #{self.words.join('--')}"
    self.words.push(self.force_words) unless self.force_words.empty?
    puts "Force words used |#{self.force_words.join('--')}|"
    puts "All words with force words |#{self.words.join('--')}|"
    if self.words.length<(FIRST_WORDS+SECOND_WORDS+ASSASSIN_WORDS)
      self.words.push('???'*(FIRST_WORDS+SECOND_WORDS+ASSASSIN_WORDS-self.words.length))#in case not enough words
      puts "Had to add extra ??? words"
    end
    puts "=================="

    self.setup_words

    assigned_user_names=self.playing_user_names.dup
    assigned_user_names.delete(self.blue_agent) unless self.blue_agent.nil?
    assigned_user_names.delete(self.red_agent) unless self.red_agent.nil?

    self.blue_team=assigned_user_names.dup
    self.red_team=self.blue_team.sample((assigned_user_names.length/2).floor)
    self.blue_team-=self.red_team

    self.red_team.unshift(self.red_agent) unless self.red_agent.nil?
    self.blue_team.unshift(self.blue_agent) unless self.blue_agent.nil?

    self.red_agent=red_team[0] if self.red_agent.nil?
    self.blue_agent=blue_team[0] if self.blue_agent.nil?
  end

  def setup_words
    self.neutral_words=self.words.dup
    if rand(2)==0
      self.current_team='red'
      self.red_words=self.neutral_words.sample(FIRST_WORDS)
      self.neutral_words-=self.red_words
      self.blue_words=self.neutral_words.sample(SECOND_WORDS)
      self.neutral_words-=self.blue_words
      self.assassin_words=self.neutral_words.sample(ASSASSIN_WORDS)
      self.neutral_words-=self.assassin_words
    else
      self.current_team='blue'
      self.blue_words=self.neutral_words.sample(FIRST_WORDS)
      self.neutral_words-=self.blue_words
      self.red_words=self.neutral_words.sample(SECOND_WORDS)
      self.neutral_words-=self.red_words
      self.assassin_words=self.neutral_words.sample(ASSASSIN_WORDS)
      self.neutral_words-=self.assassin_words
    end
  end

  def user_in_started_game?(input_user)
    self.started && self.playing_user_names.include?(input_user.nick)
  end

  def players_joined
    self.user_hash.length
  end

  #def toggle_variant(input_variant)
  #  on_after=!self.variants.include?(input_variant)
  #  if on_after
  #    self.variants.push(input_variant)
  #  else
  #    self.variants.delete(input_variant)
  #  end
  #end

  def get_player_by_user(input_user)
    #current_name=self.playing_user_names.select{|name| self.user_hash[name] == input_user}.first
    current_name=input_user.nick #this uses user.nick, but other places use this too
    return self.player_hash[current_name] #could return nil if user doesn't exist
  end

  def user_in_started_game(input_user)
    self.user_hash.value?(input_user) and self.started
  end
end


class Player
  attr_accessor :name, :user

  def initialize()
  end

  def set_name(input_name)
    self.name=input_name
  end

  def set_user(input_user)
    self.user=input_user
  end

end