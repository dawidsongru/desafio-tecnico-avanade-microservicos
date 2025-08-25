const express = require('express');
const { register, login, verifyToken, getUser } = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/verify', verifyToken);
router.get('/user', authenticate, getUser);

module.exports = router;