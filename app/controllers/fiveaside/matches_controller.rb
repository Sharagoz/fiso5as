class Fiveaside::MatchesController < ApplicationController

  def index
    @game_week = GameWeek.find_by(access_token: params[:access_token])
    if @game_week
      @matches = @game_week.matches.with_all_data.order(:gw_fixture_no)
    else
      @matches = []
    end
  end

  def show
    if params[:id].present?
      @match = Match.with_all_data.find_by(id: params[:id])
    elsif params[:season].present? && params[:game_week].present? && params[:fixture].present?
      game_week = GameWeek.find_by(season: params[:season], gw_no: params[:game_week])
      @match = game_week.matches.with_all_data.find_by(gw_fixture_no: params[:fixture]) if game_week
    end
  end

  def new
    @match = Match.new(home_team_id: 169066, game_week: (Match.maximum(:game_week) || 0) + 1, starts_at: Time.zone.now.beginning_of_week.advance(days: 5, hours: 11, minutes: 45), ends_at: Time.zone.now.beginning_of_week.advance(days: 7, hours: 4))
  end

  def create
    @match = Match.new(match_params)
    @match.set_up_match!
    redirect_to @match
  end

  private

  def match_params
    params.require(:match).permit(:home_team_id, :away_team_id, :game_week, :starts_at, :ends_at)
  end

end
