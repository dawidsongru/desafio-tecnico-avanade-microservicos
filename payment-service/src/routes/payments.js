const express = require('express');
const { processPayment, getPayment, getPaymentsByUser } = require('../controllers/paymentController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', processPayment);
router.get('/', getPaymentsByUser);
router.get('/:id', getPayment);

module.exports = router;