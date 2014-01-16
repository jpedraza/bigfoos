class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :token_authenticatable, :omniauthable,
         :omniauth_providers => [:google_oauth2]

  has_many :players, :dependent => :destroy
  has_many :teams, :through => :players
  has_many :user_stats, :dependent => :destroy

  scope :top_scorers, -> { joins(:user_stats).select('users.*,user_stats.value AS points').where('user_stats.name = ?','scores').order('points DESC') }
  scope :top_points_per_game, -> { joins(:players).select('users.*,AVG(players.points) AS points').group('users.id').order('points DESC') }
  scope :most_games, -> { joins(:players).select('users.*,COUNT(players.id) AS games').group('users.id').order('games DESC') }
  scope :top_winners, -> { joins(:user_stats).select('users.*,user_stats.value AS wins').where('user_stats.name = ?','wins').order('wins DESC') }

  def total_points
    self.players.sum(:points)
  end

  def games
    game_ids = self.teams.pluck(:game_id)
    Game.where(:id => game_ids).all
  end

  def average_points_per_game
    self.players.average(:points)
  end

  def points_for(game)
    Player.for_user(game,self).points
  end

  def self.from_omniauth(auth)
    user = User.find_by_email(auth.info.email)
    if user
      user.provider = auth.provider
      user.uid = auth.uid
      user
    else
      where(auth.slice(:provider, :uid)).first_or_create do |user|
        user.provider = auth.provider || 'google_oauth2'
        user.uid = auth.uid
        user.name = auth.info.name
        user.email = auth.info.email
      end
    end
  end

  def last_scored_at
    s = Score.joins(:player).where('players.user_id = ?',self.id).first
    if s
      s.created_at.to_s(:long)
    else
      'N/A'
    end
  end

  ##
  # Get the stats for the user
  #
  # @return [Array]
  #
  def stats
    UserStat.select('*,(SELECT (COUNT(*)+1) FROM user_stats AS us2 WHERE us2.name = user_stats.name AND us2.user_id != '+self.id.to_s+' AND us2.value > user_stats.value ) AS rank').where('user_id = ?',self.id)
  end

  ##
  # Get a stat value for a user
  #
  # @param [String|Symbol] k
  # @param [Boolean] return_value
  # @return [Integer|Float|UserStat]
  #
  def stat(k,return_value = true)
    s = self.stats.where(:name => k.to_s).first
    if return_value
      if s
        s.value
      else
        0
      end
    else
      s
    end
  end

  ##
  # Set the stat for the user for a key
  #
  # @param [String|Symbol] k
  # @param [Integer|Float|String] v
  # @return [Boolean]
  #
  def set_stat(k,v)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = v
    s.save
  end

  ##
  # Delete the stat record for a key
  #
  # @param [String|Symbol] k
  # @return [Boolean]
  #
  def delete_stat(k)
    s = self.stat(k,false)
    if s
      s.destroy
    end
  end

  ##
  # Increase a stat value
  #
  # @param [String|Symbol] key
  # @param [Integer] increment
  # @return [Boolean]
  #
  def inc_stat(k,increment = 1)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = s.value.to_i+increment.to_i
    s.save
  end

  ##
  # Decrease a stat value
  #
  # @param [String|Symbol] key
  # @param [Integer] decrement
  # @return [Boolean]
  #
  def dec_stat(k,decrement = 1)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = s.value.to_i-decrement.to_i
    s.save
  end

end
