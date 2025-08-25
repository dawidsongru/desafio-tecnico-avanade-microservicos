const axios = require('axios');

const authenticate = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ message: 'Access denied. No token provided.' });
    }

    // Verify token with auth service
    const response = await axios.post(`${process.env.AUTH_SERVICE_URL}/api/auth/verify`, { token });
    
    if (response.data.valid) {
      req.userId = response.data.user._id;
      req.userEmail = response.data.user.email;
      next();
    } else {
      res.status(401).json({ message: 'Invalid token' });
    }
  } catch (error) {
    res.status(401).json({ message: 'Token verification failed' });
  }
};

module.exports = { authenticate };