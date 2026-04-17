import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

export const sendPushNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const notificationData = snapshot.data();

    if (!notificationData) return;

    // 1. Get the recipient's FCM Token
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token found for user: ${userId}`);
      return;
    }

    // 2. Determine notification content
    let title = "New Notification";
    let body = "";
    const senderName = notificationData.senderName || "Someone";

    switch (notificationData.type) {
      case "follow_request":
        title = "Follow Request";
        body = `${senderName} wants to follow you.`;
        break;
      case "follow":
        title = "New Follower";
        body = `${senderName} started following you.`;
        break;
      case "like":
        title = "New Like";
        body = `${senderName} liked your activity.`;
        break;
      case "like_comment":
        title = "Comment Liked";
        body = `${senderName} liked your comment.`;
        break;
      case "comment":
        title = "New Comment";
        body = `${senderName} commented: "${notificationData.text || ""}"`;
        break;
      case "message":
        title = "New Message";
        body = `${senderName}: ${notificationData.text || ""}`;
        break;
      default:
        body = notificationData.text || "You have a new update.";
    }

    // 3. Construct the Message
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {title, body},
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: notificationData.type,
      },
    };

    // 4. Send
    try {
      await admin.messaging().send(message);
      console.log(`Notification sent to ${userId}`);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  });