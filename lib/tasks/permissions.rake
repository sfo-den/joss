namespace :permissions do
  desc "Restrict permissions on reviews repository to those that need it"
  task cleanup: :environment do
    # We run this task daily on Heroku
    reviews_repo = Rails.application.settings["reviews"]
    collaborators = GITHUB.collaborators(reviews_repo)
    collaborator_logins = collaborators.collect {|c| c.login.downcase }

    open_issues = GITHUB.list_issues(reviews_repo, state: 'open')

    active_reviewers = []
    open_issues.each do |issue|
      puts issue.number
      next if issue.number == 4682
      active_reviewers << issue.body.match(/(?<=<!--reviewers-list-->)(\s*(.+?)\r?)(?=<!--end-reviewers-list-->)/)[1].split(", ").each(&:strip!).each(&:downcase!) - ["Pending"]
    end

    should_have_permissions = active_reviewers.flatten.uniq

    # Loop through each collaborator and check if they need permissions
    collaborator_logins.sort.each do |login|
      next if login == 'editorialbot'

      unless should_have_permissions.include?("@#{login}")
        GITHUB.remove_collaborator(reviews_repo, login)
      end
    end
  end
end
