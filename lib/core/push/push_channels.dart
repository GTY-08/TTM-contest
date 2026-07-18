/// Android 알림 채널 ID. Edge FCM payload 와 동일해야 한다.
abstract final class PushChannels {
  static const matchOffer = 'ttm_match_offer';
  static const matchResult = 'ttm_match_result';
  static const message = 'ttm_message';
  static const completion = 'ttm_completion';
  static const defaultChannel = 'ttm_default';
}

/// FCM data[pus_type] 및 서버 push_type 과 1:1.
abstract final class PushTypes {
  static const workerMatchOffer = 'worker_match_offer';
  static const requesterMatched = 'requester_matched';
  static const requesterMatchFailed = 'requester_match_failed';
  static const completionRequested = 'completion_requested';
  static const requestCompleted = 'request_completed';
  static const requestCancelled = 'request_cancelled';
  static const chatMessage = 'chat_message';
  static const exerciseMatchOffer = 'exercise_match_offer';
  static const exerciseMatchMatched = 'exercise_match_matched';
  static const exerciseMatchMessage = 'exercise_match_message';
  static const raidRecruitmentOffer = 'raid_recruitment_offer';
  static const raidRecruitmentApplication = 'raid_recruitment_application';
  static const raidApplicationReceived = 'raid_application_received';
  static const raidApplicationApproved = 'raid_application_approved';
  static const raidApplicationWaitlisted = 'raid_application_waitlisted';
  static const raidApplicationRejected = 'raid_application_rejected';
  static const raidParticipantJoined = 'raid_participant_joined';
  static const raidParticipantCancelled = 'raid_participant_cancelled';
  static const raidStarted = 'raid_started';
  static const raidApplicationMessage = 'raid_application_message';
}
