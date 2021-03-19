class HomeController < ApplicationController
  before_action :require_user, only: %w(profile update_profile)
  before_action :require_editor, only: %w(dashboard reviews incoming stats all in_progress)
  # layout "dashboard", only:  %w(dashboard reviews incoming stats all in_progress)

  def index
    @papers = Paper.unscoped.visible.order(accepted_at: :desc).limit(10)
  end

  def about
  end

  def dashboard
    if params[:editor]
      @editor = Editor.find_by_login(params[:editor])
    else
      @editor = current_user.editor
    end

    @reviewer = params[:reviewer].nil? ? "@arfon" : params[:reviewer]
    @reviewer_papers = Paper.unscoped.where(":reviewer = ANY(reviewers)", reviewer: @reviewer).group_by_month(:accepted_at).count

    @accepted_papers = Paper.unscoped.visible.group_by_month(:accepted_at).count
    @editor_papers = Paper.unscoped.where(editor: @editor).visible.group_by_month(:accepted_at).count

    @assignment_by_editor = Paper.unscoped.in_progress.group(:editor_id).count
    @paused_by_editor = Paper.unscoped.in_progress.where("labels->>'paused' ILIKE '%'").group(:editor_id).count

    @papers_last_week = Paper.unscoped.visible.since(1.week.ago).group(:editor_id).count
    @papers_last_month = Paper.unscoped.visible.since(1.month.ago).group(:editor_id).count
    @papers_last_3_months = Paper.unscoped.visible.since(3.months.ago).group(:editor_id).count
    @papers_last_year = Paper.unscoped.visible.since(1.year.ago).group(:editor_id).count
    @papers_all_time = Paper.unscoped.visible.since(100.year.ago).group(:editor_id).count
  end

  def incoming
    if params[:order]
      @papers = Paper.unscoped.in_progress.where(editor: nil).order(percent_complete: params[:order]).paginate(
                  page: params[:page],
                  per_page: 20
                )
    else
      @papers = Paper.in_progress.where(editor: nil).paginate(
                  page: params[:page],
                  per_page: 20
                )
    end

    @editor = current_user.editor

    render template: "home/reviews"
  end

  def reviews
    case params[:order]
    when "desc"
      @order = "desc"
    when "asc"
      @order = "asc"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    if params[:editor]
      @editor = Editor.find_by_login(params[:editor])

      @papers = Paper.unscoped.in_progress.where(editor: @editor).order(percent_complete: @order).paginate(
        page: params[:page],
        per_page: 20
      )
    else
      @papers = Paper.everything.paginate(
                  page: params[:page],
                  per_page: 20
                )
    end
  end

  def in_progress
    case params[:order]
    when "desc"
      @order = "desc"
    when "asc"
      @order = "asc"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    @editor = current_user.editor

    @papers = Paper.unscoped.in_progress.order(percent_complete: @order).paginate(
                page: params[:page],
                per_page: 20
              )

    render template: "home/reviews"
  end

  def all
    case params[:order]
    when "desc"
      @order = "desc"
    when "asc"
      @order = "asc"
    when nil
      @order = "desc"
    else
      @order = "desc"
    end

    @editor = current_user.editor

    @papers = Paper.unscoped.all.order(percent_complete: @order).paginate(
              page: params[:page],
              per_page: 20
            )


    render template: "home/reviews"
  end

  def update_profile
    check_github_username

    if current_user.update(user_params)
      redirect_back(notice: "Profile updated", fallback_location: root_path)
    end
  end

  def profile
    @user = current_user
  end

private

  def check_github_username
    if user_params.has_key?('github_username')
      if !user_params['github_username'].strip.start_with?('@')
        old = user_params['github_username']
        user_params['github_username'] = old.prepend('@')
      end
    end
  end

  def user_params
    params.require(:user).permit(:email, :github_username)
  end
end
