const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');
const Razorpay = require('razorpay');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const razorpayKeyId = defineSecret('RAZORPAY_KEY_ID');
const razorpayKeySecret = defineSecret('RAZORPAY_KEY_SECRET');

function requireStudent(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
}
async function requireShopkeeper(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const user = await db.doc(`users/${request.auth.uid}`).get();
  if (!user.exists || user.data().role !== 'shopkeeper') throw new HttpsError('permission-denied', 'Shopkeeper access required.');
}

exports.createRazorpayOrder = onCall({ secrets: [razorpayKeyId, razorpayKeySecret] }, async (request) => {
  requireStudent(request);
  const { amount, orderId } = request.data || {};
  if (!Number.isInteger(amount) || amount < 100 || typeof orderId !== 'string') throw new HttpsError('invalid-argument', 'Valid amount and order ID are required.');
  const snap = await db.doc(`orders/${orderId}`).get();
  if (!snap.exists || snap.data().studentId !== request.auth.uid || snap.data().paymentStatus !== 'unpaid') throw new HttpsError('failed-precondition', 'Order is not payable.');
  const razorpay = new Razorpay({ key_id: razorpayKeyId.value(), key_secret: razorpayKeySecret.value() });
  const order = await razorpay.orders.create({ amount, currency: 'INR', receipt: orderId, notes: { orderId, uid: request.auth.uid } });
  await snap.ref.update({ razorpayOrderId: order.id, paymentAttemptedAt: admin.firestore.FieldValue.serverTimestamp() });
  return { id: order.id, amount: order.amount, currency: order.currency, keyId: razorpayKeyId.value() };
});

exports.verifyRazorpayPayment = onCall({ secrets: [razorpayKeySecret] }, async (request) => {
  requireStudent(request);
  const { orderId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = request.data || {};
  if (!orderId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) throw new HttpsError('invalid-argument', 'Payment verification data is incomplete.');
  const ref = db.doc(`orders/${orderId}`);
  const snap = await ref.get();
  if (!snap.exists || snap.data().studentId !== request.auth.uid) throw new HttpsError('permission-denied', 'Order access denied.');
  if (snap.data().paymentStatus === 'paid') return { verified: true, alreadyPaid: true };
  const body = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expected = crypto.createHmac('sha256', razorpayKeySecret.value()).update(body).digest('hex');
  if (expected.length !== razorpaySignature.length || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(razorpaySignature))) throw new HttpsError('permission-denied', 'Payment signature verification failed.');
  await ref.update({ paymentStatus: 'paid', paymentProvider: 'razorpay', razorpayOrderId, razorpayPaymentId, paidAt: admin.firestore.FieldValue.serverTimestamp() });
  return { verified: true };
});

exports.notifyStudentOnOrderUpdate = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status && before.paymentStatus === after.paymentStatus) return;
  const user = await db.doc(`users/${after.studentId}`).get();
  const token = user.data()?.fcmToken;
  if (!token) return;

  const titleByStatus = {
    accepted: 'Order accepted',
    printing: 'Printing started',
    ready: 'Order ready for collection',
    completed: 'Order completed',
    cancelled: 'Order cancelled',
    rejected: 'Order rejected'
  };
  const title = titleByStatus[after.status] || (after.paymentStatus === 'paid' ? 'Payment received' : 'Order updated');
  const body = after.status === 'ready' ? `Order ${after.code} is ready at the campus Xerox shop.` : `Order ${after.code} is now ${after.status}.`;
  try { await messaging.send({ token, notification: { title, body }, data: { orderId: event.params.orderId, status: after.status } }); }
  catch (e) { console.error('FCM send failed', e); }
});
