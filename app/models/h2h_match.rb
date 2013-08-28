require 'open-uri'
class H2hMatch < ActiveRecord::Base
  belongs_to :home_manager, class_name: 'Manager'
  belongs_to :away_manager, class_name: 'Manager'
  belongs_to :match
  has_many :players, dependent: :destroy

  validates_presence_of :home_manager_id, :away_manager_id

  serialize :info

  def self.by_match_order
    self.order("match_order ASC")
  end

  def home_squad
    self.players.where(manager_id: home_manager_id)
  end

  def away_squad
    self.players.where(manager_id: away_manager_id)
  end

  def opposing_squad(manager)
    if manager == home_manager
      home_squad
    elsif manager == away_manager
      away_squad
    else
      raise "Cant find the right manager"
    end
  end

  def home_ahead?
    home_score > away_score
  end

  def away_ahead?
    away_score > home_score
  end

  def score_diff
    (away_score - home_score).abs
  end

  def playing_now(side)
    differentiators(side).collect{|p| p if(p.playing_now?)}.compact
  end

  def playing_later(side)
    differentiators(side).collect{|p| p if(p.playing_later?)}.compact
  end

  def fetch_data
    self.players.destroy_all
    FplScraper.new(self).scrape
    self.save!
    self.info = {home: [], away: []}
    inform_of_pending_substitutions(:home)
    inform_of_pending_substitutions(:away)
    inform_of_captain_change(:home)
    inform_of_captain_change(:away)
    self.save!
  end

  def inform_of_pending_substitutions(side)
    if side == :home
      squad = home_squad
    elsif side == :away
      squad = away_squad
    else
      raise "Unknown side: #{side}"
    end
    to_replace = squad.not_benched.didnt_play
    already_subed = []
    to_replace.each do |player|
      candidates = squad.might_play
      if sub = find_sub(player,candidates,squad,already_subed)
        already_subed << sub
        msg = "#{sub.name} will replace #{player.name}"
        msg += " (#{sub.points}pts)" unless sub.playing_later?
        self.info[side] <<  msg
      end
    end
  end

  def inform_of_captain_change(side)
    if side == :home
      squad = home_squad
    elsif side == :away
      squad = away_squad
    else
      raise "Unknown side: #{side}"
    end
    if squad.might_play.where(captain: true).count == 0
      vice_captain = squad.might_play.where(vice_captain: true).first
      if vice_captain
        msg = "Armband will switch to #{vice_captain.name}"
        msg += " (#{vice_captain.points}pts)" unless vice_captain.playing_later?
        self.info[side] << msg
      end
    end
  end

  def find_sub(player, candidates, squad, already_subed)
    if player.goal_keeper? # GK and only replace GK
      return candidates.goal_keepers.first
    elsif player.defender? && squad.not_benched.defenders.might_play.count < 3 # 3 defs required
      candidates = candidates.defenders.benched.might_play
    elsif player.forward? && squad.forwards.not_benched.might_play.count == 0 # 1 FWD required
      candidates = candidates.forwards.benched.might_play
    else # No special rule applies, take first sub
      candidates = candidates.outfield_players.benched.might_play
    end
    if !already_subed.empty?
      candidates.where!("players.id NOT IN (#{already_subed.collect{|p| p.id}.join(',')})")
    end
    return candidates.first
  end

  private

  def differentiators(side)
    differentiators = []
    if side == :home
      my_players = home_squad.not_benched
      their_players = away_squad.not_benched
    end
    if side == :away
      my_players = away_squad.not_benched
      their_players = home_squad.not_benched
    end
    my_players.each do |my_player|
      their_player = their_players.find_by(name: my_player.name)
      if !their_player  || (my_player.captain? && !their_player.captain?)
        differentiators << my_player
      end
    end
    return differentiators
  end
end
