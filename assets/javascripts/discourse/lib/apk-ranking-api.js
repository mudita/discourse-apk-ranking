import { ajax } from "discourse/lib/ajax";

export function fetchReviews(page = 0) {
  return ajax("/sideloaded-apps/reviews", { data: { page } });
}

export function fetchReview(topicId) {
  return ajax(`/sideloaded-apps/reviews/${topicId}`);
}

export function createReview(topicId, reviewData) {
  return ajax("/sideloaded-apps/reviews", {
    type: "POST",
    data: {
      topic_id: topicId,
      review: reviewData,
    },
  });
}

export function updateReview(topicId, reviewData) {
  return ajax(`/sideloaded-apps/reviews/${topicId}`, {
    type: "PUT",
    data: {
      review: reviewData,
    },
  });
}
