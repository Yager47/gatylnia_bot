# points.activity_id: the coffee or push-up set a reward was paid for, so
# removing the coffee takes its reward away too. chats.points_summary_sent_on:
# the Monday the weekly жмихкоїни summary went out, so a re-run doesn't send
# it twice.
#
# Both nullable with no default, so adding them touches only the catalog. The
# foreign key goes in unvalidated so adding it doesn't scan points under a
# lock; the next migration validates it.
class AddActivityToPointsAndPointsSummaryToChats < ActiveRecord::Migration[8.1]
  def change
    add_reference :points, :activity, index: false, foreign_key: { validate: false }
    add_column :chats, :points_summary_sent_on, :date
  end
end
