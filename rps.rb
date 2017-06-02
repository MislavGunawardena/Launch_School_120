require 'pry'

module UserInput
  SHORT_MOVE_OPTIONS = {
    'r' => 'rock',
    'p' => 'paper',
    'sc' => 'scissors',
    'l' => 'lizard',
    'sp' => 'spock'
  }

  def self.prompt_name
    loop do
      puts "What's your name?"
      name = gets.chomp.strip
      return name unless name.empty?
      puts 'Sorry, you must enter a name.'
    end
  end

  def self.select_move
    loop do
      puts 'Choose a move: rock, paper, scissors, lizard, or spock:'
      choice = gets.chomp.downcase
      choice = SHORT_MOVE_OPTIONS[choice] if short_move_input?(choice)
      return choice if valid_move_value?(choice)

      puts "Enter either 'sc' for scissors or 'sp' for spock" if choice == 's'
      puts 'The choice you made was invalid. Please make a valid move.'
    end
  end

  def self.short_move_input?(choice)
    SHORT_MOVE_OPTIONS.keys.include?(choice)
  end

  def self.valid_move_value?(move_value)
    Move::VALUES.include?(move_value)
  end

  def self.select_opponent
    opponent_name = nil
    loop do
      puts "Choose an opponent: R2D2, Hal, Chappie, Sony, Watson:"
      opponent_name = gets.chomp.downcase
      break if valid_opponent_name?(opponent_name)
      puts "You must enter a valid opponent name."
    end

    format_opponent_name(opponent_name)
  end

  def self.valid_opponent_name?(opponent_name)
    !!format_opponent_name(opponent_name)
  end

  def self.format_opponent_name(opponent_name)
    RPSGame::COMPUTER_NAMES.find { |name| name.downcase == opponent_name }
  end
end

# For each round that is played between the human and the computer, regardless
# of who won, the program examines the move that the human made and determines
# the 2 moves that the computer could have made that would have enabled it to
# win. It keeps a running count of those hypotherical moves in the
# winning_comp_moves_count instance variable of the history object.
# winning_comp_moves_count is a hash where each key is a move name that
# hypothetically, could have enabled the computer to win on some of the rounds.
# Corresponding values give the number of times each key could have enabled
# the computer to win. This information is made use of by the choose method
# of the watson object.
class MoveHistory
  attr_accessor :current_game, :games, :winning_comp_moves_count

  def initialize
    self.games = []
    self.winning_comp_moves_count = Hash.new(0)
  end

  def new_game_reset
    self.current_game = []
    games << current_game
  end

  def update(human_move_value, computer_move_value)
    update_current_game(human_move_value, computer_move_value)
    update_winning_comp_moves_count(human_move_value)
  end

  def update_current_game(human_move_value, computer_move_value)
    current_moves = {
      human: human_move_value, computer: computer_move_value
    }
    current_game << current_moves
  end

  def update_winning_comp_moves_count(human_move_value)
    winning_comp_moves = Move.will_lose_to(human_move_value)
    winning_comp_moves.each do |move_value|
      winning_comp_moves_count[move_value] += 1
    end
  end
end

class Move
  VALUES = %w[rock paper scissors lizard spock]
  DOMINANCE_RULE = {
    'rock' => %w[scissors lizard],
    'paper' => %w[rock spock],
    'scissors' => %w[paper lizard],
    'lizard' => %w[paper spock],
    'spock' => %w[rock scissors]
  }

  def self.will_lose_to(move_value)
    VALUES.select do |other_move_value|
      if DOMINANCE_RULE[move_value].include?(other_move_value)
        false
      elsif move_value == other_move_value
        false
      else
        true
      end
    end
  end

  attr_reader :value

  def initialize(value)
    @value = value
  end

  def >(other_move)
    DOMINANCE_RULE[value].include?(other_move.value)
  end
end

class Player
  attr_accessor :move, :name, :score

  def initialize
    reset_score
  end

  def reset_score
    self.score = 0
  end

  def name_length
    name.size
  end

  def move_value
    move.value
  end
end

class Human < Player
  def initialize
    super
    self.name = UserInput.prompt_name
  end

  def choose
    move_value = UserInput.select_move
    self.move = Move.new(move_value)
  end
end

class Computer < Player
  def initialize(computer_name)
    super()
    self.name = computer_name
  end

  def choose(_)
    chosen_value = Move::VALUES.sample
    self.move = Move.new(chosen_value)
  end
end

class R2D2 < Computer
  def choose(_)
    available_choices = Move::VALUES - %w[scissors] + %w[rock] * 4
    chosen_value = available_choices.sample
    self.move = Move.new(chosen_value)
  end
end

class Watson < Computer
  # The winning_comp_moves_count is a hash that contains a count for the
  # number of times each possible move value could have led to a computer
  # win in the past. The 3 move values with the largest count are first
  # chosen. Then one of these is randomly chosen as the move to be made by
  # Watson such that the probability of any one of them being chosen is
  # proportional to their count.
  def choose(history)
    winning_moves_count = history.winning_comp_moves_count
    move_value = if winning_moves_count.empty?
                   Move::VALUES.sample
                 else
                   best_move(winning_moves_count)
                 end
    self.move = Move.new(move_value)
  end

  def best_move(winning_moves_count)
    winning_moves_count = winning_moves_count.sort_by do |(_, count)|
      count
    end
    best_3_winning_moves_count = winning_moves_count.last(3).to_h
    weighted_sample(best_3_winning_moves_count)
  end

  def weighted_sample(counts)
    total = counts.inject(0) { |sum, (_, value)| sum + value }
    random_number = rand(1..total)

    running_total = 0
    counts.each do |key, value|
      running_total += value
      return key if running_total >= random_number
    end
  end
end

class Round
  attr_accessor :human, :computer, :history

  def initialize(human, computer, history)
    self.human = human
    self.computer = computer
    self.history = history
  end

  def winner
    if human.move > computer.move
      human
    elsif computer.move > human.move
      computer
    end
  end

  def won?
    !!winner
  end

  def display_result
    RPSGame.clear_screen
    puts "#{human.name} chose: #{human.move_value}"
    puts "#{computer.name} chose: #{computer.move_value}"
    if won? then puts "#{winner.name} won!"
    else         puts "It's a tie!"
    end
  end

  def play
    human.choose
    computer.choose(history)
    display_result
    history.update(human.move_value, computer.move_value)
  end
end

class Game
  WINNING_SCORE = 3

  attr_accessor :human, :computer, :history

  def initialize(human, computer, history)
    self.human = human
    self.computer = computer
    self.history = history
    self.human.reset_score
    self.computer.reset_score
    history.new_game_reset
  end

  def display_score
    name_field_size = longer_name_size
    puts '-----------'
    puts 'Score Board'
    puts "#{human.name.ljust(name_field_size)}: #{human.score}"
    puts "#{computer.name.ljust(name_field_size)}: #{computer.score}"
    puts '-----------'
  end

  def longer_name_size
    players = [human, computer]
    longer_name = players.max_by(&:name_length).name_length
    longer_name.size
  end

  def update_score(winner)
    winner.score += 1 if winner
  end

  def game_over?
    human.score == WINNING_SCORE || computer.score == WINNING_SCORE
  end

  def winner
    case WINNING_SCORE
    when human.score    then human
    when computer.score then computer
    end
  end

  def display_result
    puts "*** #{winner.name} won the game! ***"
  end

  def play
    RPSGame.clear_screen
    puts "\nNEW GAME!\n\n"
    display_score
    loop do
      round = Round.new(human, computer, history)
      round.play
      update_score(round.winner)
      display_score
      break if game_over?
    end
    display_result
  end
end

# Game Orchestration Engine
class RPSGame
  COMPUTER_NAMES = ['R2D2', 'Hal', 'Chappie', 'Sony', 'Watson']

  attr_accessor :human, :computer, :history

  def self.clear_screen
    system('clear') || system('cls')
  end

  def self.prompt_enter
    puts "Press enter to continue."
    gets
  end

  def initialize
    RPSGame.clear_screen
    self.human = Human.new
    opponent_name = UserInput.select_opponent
    self.computer = new_computer(opponent_name)
    self.history = MoveHistory.new
  end

  def new_computer(name)
    case name
    when 'R2D2'   then R2D2.new(name)
    when 'Watson' then Watson.new(name)
    else               Computer.new(name)
    end
  end

  def display_welcome_message
    puts "Welcome to Rock, Paper, Scissors, Spock, Lizard!"
  end

  def display_goodbye_message
    puts "Thanks for playing Rock, Paper, Scissors, Spock, Lizard. Goodbye!"
  end

  def play_again?
    response = ''
    loop do
      puts "Do you want to play again? (y/n)"
      response = gets.chomp.downcase
      break if %w[y n yes no].include?(response)
      puts "You should enter either 'y' or 'n'."
    end
    %w[y yes].include?(response)
  end

  def display_opponent
    puts "You are playing against #{computer.name}."
  end

  def play
    display_welcome_message
    display_opponent
    RPSGame.prompt_enter
    loop do
      game = Game.new(human, computer, history)
      game.play
      break unless play_again?
    end
    display_goodbye_message
  end
end

RPSGame.new.play
