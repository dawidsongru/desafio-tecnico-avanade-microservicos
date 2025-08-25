const Payment = require('../models/Payment');
const axios = require('axios');

const processPayment = async (req, res, next) => {
  try {
    const { orderId, amount, currency, paymentMethod, paymentDetails } = req.body;
    const userId = req.userId;

    // Verify order exists and amount matches
    try {
      const orderResponse = await axios.get(`${process.env.ORDER_SERVICE_URL}/api/orders/${orderId}`, {
        headers: {
          'Authorization': `Bearer ${req.headers.authorization?.replace('Bearer ', '')}`
        }
      });

      if (orderResponse.data.totalAmount !== amount) {
        return res.status(400).json({ message: 'Amount does not match order total' });
      }
    } catch (error) {
      return res.status(404).json({ message: 'Order not found' });
    }

    // Simulate payment processing
    // In a real application, this would integrate with a payment gateway
    const isPaymentSuccessful = Math.random() > 0.1; // 90% success rate for simulation

    const payment = new Payment({
      orderId,
      userId,
      amount,
      currency,
      paymentMethod,
      paymentDetails,
      status: isPaymentSuccessful ? 'completed' : 'failed'
    });

    await payment.save();

    if (isPaymentSuccessful) {
      // Update order status to confirmed
      try {
        await axios.patch(
          `${process.env.ORDER_SERVICE_URL}/api/orders/${orderId}/status`,
          { status: 'confirmed' },
          {
            headers: {
              'Authorization': `Bearer ${req.headers.authorization?.replace('Bearer ', '')}`
            }
          }
        );
      } catch (error) {
        console.error('Failed to update order status:', error.message);
      }

      res.status(201).json({
        message: 'Payment processed successfully',
        payment
      });
    } else {
      res.status(400).json({
        message: 'Payment failed',
        payment
      });
    }
  } catch (error) {
    next(error);
  }
};

const getPayment = async (req, res, next) => {
  try {
    const paymentId = req.params.id;
    const userId = req.userId;

    const payment = await Payment.findOne({ _id: paymentId, userId });
    
    if (!payment) {
      return res.status(404).json({ message: 'Payment not found' });
    }

    res.json(payment);
  } catch (error) {
    next(error);
  }
};

const getPaymentsByUser = async (req, res, next) => {
  try {
    const userId = req.userId;
    const payments = await Payment.find({ userId }).sort({ createdAt: -1 });
    
    res.json(payments);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  processPayment,
  getPayment,
  getPaymentsByUser
};